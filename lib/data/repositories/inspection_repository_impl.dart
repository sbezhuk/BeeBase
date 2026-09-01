import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_mutation_store.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/extensions/inspection_extension.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/repositories/inspection_cache_merger.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/inspection_sync_status.dart';
import 'package:beebase/domain/enum/inspection_type.dart';
import 'package:beebase/domain/repositories/inspection_reader.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

const _inspectionEntityType = 'inspection';

/// Must match `HiveRepositoryImpl`'s private `_hiveEntityType` — used here
/// only to look up a still-pending hive `create` operation when an
/// inspection is created offline under a hive that is itself only a local
/// placeholder (see [InspectionRepositoryImpl._createOffline]).
const _hiveEntityType = 'hive';

/// Cache key both this repository and its DI registration of
/// `LocalDataSource<List<InspectionResponse>>` agree on. One cache holds the
/// caller's inspections across every hive — see [InspectionCacheMerger] for
/// how reads are filtered back down to a single hive.
const inspectionCacheKey = 'cached_inspections';

/// The reserved key inside [OfflineOperation.payload] that carries the
/// owning hive's id alongside the [InspectionRequest] fields — never part of
/// the actual HTTP body (the hive id travels in the URL, added by
/// [IInspectionDataSource] itself), only read back by this repository/
/// [InspectionOperationHandler] when replaying a queued operation.
const _payloadHiveIdKey = 'hiveId';

final class InspectionRepositoryImpl extends Repository implements IInspectionReader, IInspectionWriter {
  InspectionRepositoryImpl({
    required this.dataSource,
    required this.localDataSource,
    required this.connectivity,
    required this.operationQueue,
    required this.offlineMutationStore,
    this.cacheMerger = const InspectionCacheMerger(),
  });

  final IInspectionDataSource dataSource;
  final LocalDataSource<List<InspectionResponse>> localDataSource;
  final IConnectivityService connectivity;
  final OperationQueue operationQueue;
  final OfflineMutationStore offlineMutationStore;
  final InspectionCacheMerger cacheMerger;

  @override
  Future<Either<Failure, Page<Inspection>>> getInspections({
    required String hiveId,
    required int page,
    required int limit,
  }) async {
    final pendingOps = await _inspectionOperations();
    if (!await connectivity.isOnline) {
      return _cachedPage(hiveId, pendingOps);
    }

    final result = await on(() async {
      final paginated = await dataSource.getInspections(hiveId, PageRequest(page: page, limit: limit));
      late List<InspectionResponse> merged;
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
        return _cachedPage(hiveId, pendingOps);
      },
      (data) async {
        final (merged, hasNext) = data;
        final forHive = merged.where((response) => response.hiveId == hiveId).toList();
        return Right(Page(items: cacheMerger.toEntities(forHive, pendingOps), hasNext: hasNext));
      },
    );
  }

  @override
  Future<Either<Failure, Inspection>> getInspection({required String hiveId, required String id}) {
    return on(() async => (await dataSource.getInspection(hiveId, id)).toEntity());
  }

  @override
  Future<Either<Failure, Inspection>> createInspection({
    required String hiveId,
    required DateTime date,
    required InspectionType type,
    String? notes,
  }) async {
    if (!await connectivity.isOnline) {
      return _createOffline(hiveId: hiveId, date: date, type: type, notes: notes);
    }

    final request = InspectionRequest(date: date, type: type, notes: notes);
    final result = await on(() async {
      final response = await dataSource.createInspection(hiveId, request);
      await localDataSource.modify((current) => [...(current ?? const []), response]);
      return response;
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _createOffline(hiveId: hiveId, date: date, type: type, notes: notes);
    }, (response) => Future.value(Right(response.toEntity())));
  }

  /// An entity with a not-yet-synced local edit always stays on the local
  /// path — even while online — so a further edit never races ahead of that
  /// pending operation by hitting the API directly. A still-local
  /// (never-created-server-side) id always has such a pending operation by
  /// construction; the [LocalIdGenerator.isLocal] branch below is only a
  /// defensive fallback for that invariant being violated.
  @override
  Future<Either<Failure, Inspection>> updateInspection({
    required String hiveId,
    required String id,
    required DateTime date,
    required InspectionType type,
    String? notes,
  }) async {
    final pending = await _pendingOperationFor(id);
    if (pending != null) {
      return _updateOffline(hiveId: hiveId, id: id, date: date, type: type, notes: notes);
    }
    if (LocalIdGenerator.isLocal(id)) {
      return const Left(InternalFailure(ErrorTextKey('inspection.errors.pendingSync')));
    }
    if (!await connectivity.isOnline) {
      return _updateOffline(hiveId: hiveId, id: id, date: date, type: type, notes: notes);
    }

    final request = InspectionRequest(date: date, type: type, notes: notes);
    final result = await on(() async => (await dataSource.updateInspection(hiveId, id, request)).toEntity());

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _updateOffline(hiveId: hiveId, id: id, date: date, type: type, notes: notes);
    }, (inspection) => Future.value(Right(inspection)));
  }

  /// A never-synced local entity is always deletable, online or off — there's
  /// nothing server-side to reconcile, so this just drops its placeholder and
  /// cancels its pending `CREATE` operation. A synced entity requires live
  /// connectivity to delete, since deleting it is a real server call with no
  /// offline-queued equivalent.
  @override
  Future<Either<Failure, void>> deleteInspection({required String hiveId, required String id}) async {
    if (LocalIdGenerator.isLocal(id)) {
      return _deleteLocalOnly(id);
    }
    if (!await connectivity.isOnline) {
      return const Left(InternalFailure(ErrorTextKey('inspection.errors.deleteRequiresConnection')));
    }
    return _deleteOnline(hiveId: hiveId, id: id);
  }

  Future<Either<Failure, void>> _deleteLocalOnly(String id) async {
    await _purgeLocal(id);
    return const Right(null);
  }

  /// A 404 here means the server has already forgotten this entity — a stale
  /// local record left behind by, e.g., a previous sync that succeeded
  /// server-side but never reconciled locally, or a delete from another
  /// device/session. The desired end state (no such inspection) is already
  /// true, so this is treated as a successful delete rather than a failure —
  /// see [on]'s `ignoreStatusCode`.
  Future<Either<Failure, void>> _deleteOnline({required String hiveId, required String id}) async {
    final result = await on(() => dataSource.deleteInspection(hiveId, id), ignoreStatusCode: 404, onIgnoredStatusCode: () {});

    return result.fold((failure) async => Left(failure), (_) async {
      await _purgeLocal(id);
      return const Right(null);
    });
  }

  /// Drops [id]'s cache entry and any lingering pending operation for it —
  /// used both for a never-synced entity's local-only delete and to clean up
  /// after a synced entity is deleted server-side, so neither can reappear
  /// from the cache the next time the list is read offline.
  Future<void> _purgeLocal(String id) async {
    await localDataSource.modify((current) => (current ?? const []).where((response) => response.id != id).toList());
    final pending = await _pendingOperationFor(id);
    if (pending != null) {
      await operationQueue.remove(pending.id);
    }
  }

  /// Saves the local placeholder and enqueues its sync operation atomically
  /// (see [OfflineMutationStore]) — never local-entity-without-operation or
  /// the reverse.
  ///
  /// If [hiveId] is itself still a local placeholder (its own hive was also
  /// created offline and hasn't synced), this inspection's `create` operation
  /// is linked to that hive's pending `create` operation via
  /// [OfflineOperation.dependsOnOperationId] — otherwise `SyncEngine` could
  /// try to create this inspection under a hive id the backend has never
  /// heard of. See [InspectionOperationHandler] for how that dependency is
  /// resolved once it syncs.
  Future<Either<Failure, Inspection>> _createOffline({
    required String hiveId,
    required DateTime date,
    required InspectionType type,
    String? notes,
  }) async {
    final now = DateTime.now();
    final localId = LocalIdGenerator.generate();
    final dependsOnOperationId = LocalIdGenerator.isLocal(hiveId) ? await _pendingHiveCreateOperationId(hiveId) : null;
    final placeholder = InspectionResponse(
      id: localId,
      hiveId: hiveId,
      date: date,
      type: type,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    await offlineMutationStore.saveWithPendingOperation<List<InspectionResponse>>(
      cacheKey: inspectionCacheKey,
      mutate: (current) => [...(current ?? const []), placeholder],
      toJson: (list) => list.map((response) => response.toJson()).toList(),
      fromJson: (json) =>
          (json as List<dynamic>).map((item) => InspectionResponse.fromJson(item as Map<String, dynamic>)).toList(),
      operation: OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: _inspectionEntityType,
        operationType: OperationType.create,
        payload: {
          _payloadHiveIdKey: hiveId,
          ...InspectionRequest(date: date, type: type, notes: notes).toJson(),
        },
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: localId,
        dependsOnOperationId: dependsOnOperationId,
      ),
    );
    return Right(placeholder.toEntity().copyWith(syncStatus: InspectionSyncStatus.pending));
  }

  /// The still-pending (or already-processed but not-yet-synced) `create`
  /// operation for the hive identified by the local id [hiveId] — `null` if
  /// none is found, which would mean the invariant "a local hive id always
  /// has a pending create operation" was violated elsewhere.
  Future<String?> _pendingHiveCreateOperationId(String hiveId) async {
    final operations = await operationQueue.all();
    for (final operation in operations) {
      if (operation.entityType == _hiveEntityType &&
          operation.localEntityId == hiveId &&
          operation.operationType == OperationType.create) {
        return operation.id;
      }
    }
    return null;
  }

  /// Updates the cached entity and folds the change into the single
  /// outstanding pending operation for [id] — a still-pending `CREATE` stays
  /// a `CREATE` with the newer payload; an already-synced entity gets a
  /// fresh `UPDATE` the first time, then that same `UPDATE` is reused
  /// (payload replaced, `version` bumped) on every further edit before it
  /// syncs. Returns immediately with the locally-held state, no network
  /// round trip needed.
  Future<Either<Failure, Inspection>> _updateOffline({
    required String hiveId,
    required String id,
    required DateTime date,
    required InspectionType type,
    String? notes,
  }) async {
    final now = DateTime.now();
    final request = InspectionRequest(date: date, type: type, notes: notes);
    InspectionResponse? updatedResponse;

    await offlineMutationStore.saveWithConsolidatedOperation<List<InspectionResponse>>(
      cacheKey: inspectionCacheKey,
      mutate: (current) {
        final list = current ?? const <InspectionResponse>[];
        InspectionResponse? match;
        for (final response in list) {
          if (response.id == id) {
            match = response;
            break;
          }
        }
        final response = request.toResponse(id: id, hiveId: hiveId, createdAt: match?.createdAt ?? now, updatedAt: now);
        updatedResponse = response;
        return [
          for (final existing in list)
            if (existing.id != id) existing,
          response,
        ];
      },
      toJson: (list) => list.map((response) => response.toJson()).toList(),
      fromJson: (json) =>
          (json as List<dynamic>).map((item) => InspectionResponse.fromJson(item as Map<String, dynamic>)).toList(),
      entityType: _inspectionEntityType,
      entityId: id,
      operation: () => OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: _inspectionEntityType,
        operationType: OperationType.update,
        payload: {_payloadHiveIdKey: hiveId, ...request.toJson()},
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: id,
      ),
      mergeInto: (existing) => existing.copyWith(
        payload: {_payloadHiveIdKey: hiveId, ...request.toJson()},
        status: OperationStatus.pending,
        updatedAt: now,
        version: existing.version + 1,
      ),
    );

    return Right(updatedResponse!.toEntity().copyWith(syncStatus: InspectionSyncStatus.pending));
  }

  Future<List<OfflineOperation>> _inspectionOperations() async {
    return (await operationQueue.all()).where((operation) => operation.entityType == _inspectionEntityType).toList();
  }

  /// The current non-synced operation for [id] (a pending `CREATE` if [id]
  /// is still local, or a pending/failed `UPDATE` if it's a synced entity
  /// with an unsynced edit) — `null` if [id] has nothing outstanding.
  Future<OfflineOperation?> _pendingOperationFor(String id) async {
    final matches = (await _inspectionOperations()).where(
      (operation) => operation.localEntityId == id && operation.status != OperationStatus.synced,
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
  ///
  /// Never fails: a `null` cache (inspections have never been fetched for
  /// this hive, or at all) is treated the same as a populated cache with
  /// zero entries for [hiveId] — both mean "nothing to show right now", so
  /// the empty-list view is shown rather than an error screen. This is only
  /// reached for a connectivity-shaped problem (offline, or an online
  /// request that failed for a non-`ServerFailure` reason) — a real
  /// `ServerFailure` is never routed through here (see [getInspections]).
  Future<Either<Failure, Page<Inspection>>> _cachedPage(String hiveId, List<OfflineOperation> pendingOps) async {
    final all = await localDataSource.read();
    final cached = (all ?? const []).where((response) => response.hiveId == hiveId).toList();
    return Right(Page(items: cacheMerger.toEntities(cached, pendingOps), hasNext: false));
  }
}
