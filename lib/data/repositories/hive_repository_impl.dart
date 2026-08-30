import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/cancellation_exception.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_mutation_store.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/extensions/hive_extension.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/repositories/hive_cache_merger.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/hive_sync_status.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

const _hiveEntityType = 'hive';

/// Cache key both this repository and its DI registration of
/// `LocalDataSource<List<HiveResponse>>` agree on. One cache holds the
/// caller's hives across every apiary — see [HiveCacheMerger] for how reads
/// are filtered back down to a single apiary.
const hiveCacheKey = 'cached_hives';

/// The reserved key inside [OfflineOperation.payload] that carries the
/// owning apiary's id alongside the [HiveRequest] fields — never part of the
/// actual HTTP body (the apiary id travels in the create request's own
/// `apiary_id` field, added by [IHiveDataSource.createHive] itself, and
/// nowhere at all on update), only read back by this repository/
/// [HiveOperationHandler] when replaying a queued operation.
const _payloadApiaryIdKey = 'apiaryId';

final class HiveRepositoryImpl extends Repository
    implements IHiveReader, IHiveWriter {
  HiveRepositoryImpl({
    required this.dataSource,
    required this.localDataSource,
    required this.connectivity,
    required this.operationQueue,
    required this.offlineMutationStore,
    this.cacheMerger = const HiveCacheMerger(),
  });

  final IHiveDataSource dataSource;
  final LocalDataSource<List<HiveResponse>> localDataSource;
  final IConnectivityService connectivity;
  final OperationQueue operationQueue;
  final OfflineMutationStore offlineMutationStore;
  final HiveCacheMerger cacheMerger;

  /// `GET /api/v1/hives` has no apiary filter — it's a page of *all* of the
  /// caller's hives. This fetches/caches that global page exactly like
  /// `ApiaryRepositoryImpl` does for apiaries, then filters the merged cache
  /// down to [apiaryId] only for the page actually returned to the caller.
  @override
  Future<Either<Failure, Page<Hive>>> getHives({
    required String apiaryId,
    required int page,
    required int limit,
  }) async {
    final pendingOps = await _hiveOperations();
    if (!await connectivity.isOnline) {
      return _cachedPageOrFailure(
        apiaryId,
        const InternalFailure(
          ErrorTextKey('core.errors.unexpectedNetworkError'),
        ),
        pendingOps,
      );
    }

    final result = await on(() async {
      final paginated = await dataSource.getHives(
        PageRequest(page: page, limit: limit),
      );
      late List<HiveResponse> merged;
      await localDataSource.modify((current) {
        final oldCache = current ?? const [];
        merged = page <= 1
            ? cacheMerger.mergeFirstPage(paginated.items, oldCache, pendingOps)
            : cacheMerger.appendPage(paginated.items, oldCache);
        return merged;
      });
      return (merged, paginated.pagination.hasNext);
    });

    return result.fold(
      (failure) async {
        if (failure is ServerFailure) {
          return Left(failure);
        }
        return _cachedPageOrFailure(apiaryId, failure, pendingOps);
      },
      (data) async {
        final (merged, hasNext) = data;
        final forApiary = merged
            .where((response) => response.apiaryId == apiaryId)
            .toList();
        return Right(
          Page(
            items: cacheMerger.toEntities(forApiary, pendingOps),
            hasNext: hasNext,
          ),
        );
      },
    );
  }

  @override
  Future<Either<Failure, Hive>> getHive(String id) {
    return on(() async => (await dataSource.getHive(id)).toEntity());
  }

  @override
  Future<Either<Failure, Hive>> createHive({
    required String apiaryId,
    required String name,
    String? notes,
  }) async {
    if (!await connectivity.isOnline) {
      return _createOffline(apiaryId: apiaryId, name: name, notes: notes);
    }

    final request = HiveRequest(name: name, notes: notes);
    final result = await on(() async {
      final response = await dataSource.createHive(request, apiaryId: apiaryId);
      await localDataSource.modify(
        (current) => [...(current ?? const []), response],
      );
      return response;
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _createOffline(apiaryId: apiaryId, name: name, notes: notes);
    }, (response) => Future.value(Right(response.toEntity())));
  }

  /// An entity with a not-yet-synced local edit always stays on the local
  /// path — even while online — so a further edit never races ahead of that
  /// pending operation by hitting the API directly. A still-local
  /// (never-created-server-side) id always has such a pending operation by
  /// construction; the [LocalIdGenerator.isLocal] branch below is only a
  /// defensive fallback for that invariant being violated.
  @override
  Future<Either<Failure, Hive>> updateHive({
    required String apiaryId,
    required String id,
    required String name,
    String? notes,
  }) async {
    final pending = await _pendingOperationFor(id);
    if (pending != null) {
      return _updateOffline(
        apiaryId: apiaryId,
        id: id,
        name: name,
        notes: notes,
      );
    }
    if (LocalIdGenerator.isLocal(id)) {
      return const Left(
        InternalFailure(ErrorTextKey('hive.errors.pendingSync')),
      );
    }
    if (!await connectivity.isOnline) {
      return _updateOffline(
        apiaryId: apiaryId,
        id: id,
        name: name,
        notes: notes,
      );
    }

    final request = HiveRequest(name: name, notes: notes);
    final result = await on(
      () async => (await dataSource.updateHive(id, request)).toEntity(),
    );

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _updateOffline(
        apiaryId: apiaryId,
        id: id,
        name: name,
        notes: notes,
      );
    }, (hive) => Future.value(Right(hive)));
  }

  /// A never-synced local entity is always deletable, online or off — there's
  /// nothing server-side to reconcile, so this just drops its placeholder and
  /// cancels its pending `CREATE` operation. A synced entity requires live
  /// connectivity to delete, since deleting it is a real server call with no
  /// offline-queued equivalent.
  @override
  Future<Either<Failure, void>> deleteHive(String id) async {
    if (LocalIdGenerator.isLocal(id)) {
      return _deleteLocalOnly(id);
    }
    if (!await connectivity.isOnline) {
      return const Left(
        InternalFailure(ErrorTextKey('hive.errors.deleteRequiresConnection')),
      );
    }
    return _deleteOnline(id);
  }

  Future<Either<Failure, void>> _deleteLocalOnly(String id) async {
    await _purgeLocal(id);
    return const Right(null);
  }

  /// A 404 here means the server has already forgotten this entity — a stale
  /// local record left behind by, e.g., a previous sync that succeeded
  /// server-side but never reconciled locally, or a delete from another
  /// device/session. The desired end state (no such hive) is already true,
  /// so this is treated as a successful delete rather than a failure. Any
  /// other server error still surfaces normally via [on]'s standard
  /// translation.
  Future<Either<Failure, void>> _deleteOnline(String id) async {
    try {
      await dataSource.deleteHive(id);
    } on ServerException catch (e) {
      if (e.statusCode != 404) {
        return Left(
          ServerFailure(code: e.code, message: e.message, fields: e.fields),
        );
      }
    } on CancellationException catch (e) {
      return Left(CancellationFailure(e.message));
    } on InternalException catch (e) {
      return Left(InternalFailure(e.message));
    }
    await _purgeLocal(id);
    return const Right(null);
  }

  /// Drops [id]'s cache entry and any lingering pending operation for it —
  /// used both for a never-synced entity's local-only delete and to clean up
  /// after a synced entity is deleted server-side, so neither can reappear
  /// from the cache the next time the list is read offline.
  Future<void> _purgeLocal(String id) async {
    await localDataSource.modify(
      (current) =>
          (current ?? const []).where((response) => response.id != id).toList(),
    );
    final pending = await _pendingOperationFor(id);
    if (pending != null) {
      await operationQueue.remove(pending.id);
    }
  }

  /// Saves the local placeholder and enqueues its sync operation atomically
  /// (see [OfflineMutationStore]) — never local-entity-without-operation or
  /// the reverse.
  Future<Either<Failure, Hive>> _createOffline({
    required String apiaryId,
    required String name,
    String? notes,
  }) async {
    final now = DateTime.now();
    final localId = LocalIdGenerator.generate();
    final placeholder = HiveResponse(
      id: localId,
      apiaryId: apiaryId,
      name: name,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    await offlineMutationStore.saveWithPendingOperation<List<HiveResponse>>(
      cacheKey: hiveCacheKey,
      mutate: (current) => [...(current ?? const []), placeholder],
      toJson: (list) => list.map((response) => response.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>)
          .map((item) => HiveResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
      operation: OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: _hiveEntityType,
        operationType: OperationType.create,
        payload: {
          _payloadApiaryIdKey: apiaryId,
          ...HiveRequest(name: name, notes: notes).toJson(),
        },
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: localId,
      ),
    );
    return Right(
      placeholder.toEntity().copyWith(syncStatus: HiveSyncStatus.pending),
    );
  }

  /// Updates the cached entity and folds the change into the single
  /// outstanding pending operation for [id] — a still-pending `CREATE` stays
  /// a `CREATE` with the newer payload; an already-synced entity gets a
  /// fresh `UPDATE` the first time, then that same `UPDATE` is reused
  /// (payload replaced, `version` bumped) on every further edit before it
  /// syncs. Returns immediately with the locally-held state, no network
  /// round trip needed.
  Future<Either<Failure, Hive>> _updateOffline({
    required String apiaryId,
    required String id,
    required String name,
    String? notes,
  }) async {
    final now = DateTime.now();
    final request = HiveRequest(name: name, notes: notes);
    HiveResponse? updatedResponse;

    await offlineMutationStore
        .saveWithConsolidatedOperation<List<HiveResponse>>(
          cacheKey: hiveCacheKey,
          mutate: (current) {
            final list = current ?? const <HiveResponse>[];
            HiveResponse? match;
            for (final response in list) {
              if (response.id == id) {
                match = response;
                break;
              }
            }
            final response = request.toResponse(
              id: id,
              apiaryId: apiaryId,
              createdAt: match?.createdAt ?? now,
              updatedAt: now,
            );
            updatedResponse = response;
            return [
              for (final existing in list)
                if (existing.id != id) existing,
              response,
            ];
          },
          toJson: (list) => list.map((response) => response.toJson()).toList(),
          fromJson: (json) => (json as List<dynamic>)
              .map(
                (item) => HiveResponse.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
          entityType: _hiveEntityType,
          entityId: id,
          operation: () => OfflineOperation(
            id: LocalIdGenerator.generate(),
            entityType: _hiveEntityType,
            operationType: OperationType.update,
            payload: {_payloadApiaryIdKey: apiaryId, ...request.toJson()},
            status: OperationStatus.pending,
            createdAt: now,
            updatedAt: now,
            localEntityId: id,
          ),
          mergeInto: (existing) => existing.copyWith(
            payload: {_payloadApiaryIdKey: apiaryId, ...request.toJson()},
            status: OperationStatus.pending,
            updatedAt: now,
            version: existing.version + 1,
          ),
        );

    return Right(
      updatedResponse!.toEntity().copyWith(syncStatus: HiveSyncStatus.pending),
    );
  }

  Future<List<OfflineOperation>> _hiveOperations() async {
    return (await operationQueue.all())
        .where((operation) => operation.entityType == _hiveEntityType)
        .toList();
  }

  /// The current non-synced operation for [id] (a pending `CREATE` if [id]
  /// is still local, or a pending/failed `UPDATE` if it's a synced entity
  /// with an unsynced edit) — `null` if [id] has nothing outstanding.
  Future<OfflineOperation?> _pendingOperationFor(String id) async {
    final matches = (await _hiveOperations()).where(
      (operation) =>
          operation.localEntityId == id &&
          operation.status != OperationStatus.synced,
    );
    if (matches.isEmpty) {
      return null;
    }
    return matches.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
  }

  /// `hasNext: false` — there's no fresh pagination metadata while degraded
  /// or offline, so "load more" simply isn't offered again until the next
  /// successful online fetch; pull-to-refresh is the existing "try again"
  /// affordance once back online.
  Future<Either<Failure, Page<Hive>>> _cachedPageOrFailure(
    String apiaryId,
    Failure failure,
    List<OfflineOperation> pendingOps,
  ) async {
    final cached = ((await localDataSource.read()) ?? const [])
        .where((response) => response.apiaryId == apiaryId)
        .toList();
    if (cached.isEmpty) {
      return Left(failure);
    }
    return Right(
      Page(items: cacheMerger.toEntities(cached, pendingOps), hasNext: false),
    );
  }
}
