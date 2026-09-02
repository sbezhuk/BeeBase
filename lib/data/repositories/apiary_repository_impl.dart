import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_mutation_store.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/extensions/apiary_extension.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/repositories/apiary_cache_merger.dart';
import 'package:beebase/data/repositories/owner_operation_status.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/local/apiary_sync_status.dart';
import 'package:beebase/domain/enum/local/media_sync_status.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

const _apiaryEntityType = 'apiary';

/// Cache key both this repository and its DI registration of
/// `LocalDataSource<List<ApiaryResponse>>` agree on.
const apiaryCacheKey = 'cached_apiaries';

final class ApiaryRepositoryImpl extends Repository implements IApiaryReader, IApiaryWriter {
  ApiaryRepositoryImpl({
    required this.dataSource,
    required this.localDataSource,
    required this.connectivity,
    required this.operationQueue,
    required this.offlineMutationStore,
    this.cacheMerger = const ApiaryCacheMerger(),
  });

  final IApiaryDataSource dataSource;
  final LocalDataSource<List<ApiaryResponse>> localDataSource;
  final IConnectivityService connectivity;
  final OperationQueue operationQueue;
  final OfflineMutationStore offlineMutationStore;
  final ApiaryCacheMerger cacheMerger;

  /// Network-first with a cache fallback: the repository is the only place
  /// that decides whether the list comes from the API or from the last
  /// synchronized copy, and the only place that accumulates pages into one
  /// list — feature code always just sees the current [Page<Apiary>] to
  /// render, never splicing pages together itself. Page 1 (initial load or
  /// refresh) replaces the cache; page 2+ appends to it (see
  /// [ApiaryCacheMerger]).
  @override
  Future<Either<Failure, Page<Apiary>>> getApiaries({required int page, required int limit}) async {
    final pendingOps = await _apiaryOperations();
    if (!await connectivity.isOnline) {
      return _cachedPageOrFailure(const InternalFailure(ErrorTextKey('core.errors.unexpected_network_error')), pendingOps);
    }

    final result = await on(() async {
      final paginated = await dataSource.getApiaries(PageRequest(page: page, limit: limit));
      late List<ApiaryResponse> merged;
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
        return _cachedPageOrFailure(failure, pendingOps);
      },
      (data) async {
        final (merged, hasNext) = data;
        return Right(Page(items: cacheMerger.toEntities(merged, pendingOps), hasNext: hasNext));
      },
    );
  }

  @override
  Future<Either<Failure, Apiary>> getApiary(String id) {
    return on(() async => (await dataSource.getApiary(id)).toEntity());
  }

  @override
  Future<Apiary?> getCachedApiary(String id) async {
    final cached = await localDataSource.read() ?? const <ApiaryResponse>[];
    ApiaryResponse? match;
    for (final response in cached) {
      if (response.id == id) {
        match = response;
        break;
      }
    }
    if (match == null) return null;

    final pendingOps = await _apiaryOperations();
    return cacheMerger.toEntities([match], pendingOps).first;
  }

  @override
  Future<Either<Failure, Apiary>> createApiary({
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  }) async {
    if (!await connectivity.isOnline) {
      return _createOffline(name: name, description: description, location: location, lat: lat, lon: lon);
    }

    final request = ApiaryRequest(name: name, description: description, location: location, lat: lat, lon: lon);
    final result = await on(() async {
      final response = await dataSource.createApiary(request);
      await localDataSource.modify((current) => [...(current ?? const []), response]);
      return response;
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _createOffline(name: name, description: description, location: location, lat: lat, lon: lon);
    }, (response) => Future.value(Right(response.toEntity())));
  }

  /// An entity with a not-yet-synced local edit always stays on the local
  /// path — even while online — so a further edit never races ahead of that
  /// pending operation by hitting the API directly (see item #10: coming
  /// back online only makes sync *available*, it never bypasses the
  /// explicit "Sync now" policy). A still-local (never-created-server-side)
  /// id always has such a pending operation by construction; the
  /// [LocalIdGenerator.isLocal] branch below is only a defensive fallback
  /// for that invariant being violated.
  @override
  Future<Either<Failure, Apiary>> updateApiary({
    required String id,
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  }) async {
    final pending = await _pendingOperationFor(id);
    if (pending != null) {
      return _updateOffline(id: id, name: name, description: description, location: location, lat: lat, lon: lon);
    }
    if (LocalIdGenerator.isLocal(id)) {
      return const Left(InternalFailure(ErrorTextKey('core.errors.pending_sync')));
    }
    if (!await connectivity.isOnline) {
      return _updateOffline(id: id, name: name, description: description, location: location, lat: lat, lon: lon);
    }

    // images is never set here: a plain field edit never touches attached
    // media, and omitting the key (see [ApiaryRequest.images]) is exactly
    // what tells apiary-service to leave it alone. Attaching new media goes
    // through [addApiaryImage] instead.
    final request = ApiaryRequest(name: name, description: description, location: location, lat: lat, lon: lon);
    final result = await on(() async {
      final response = await dataSource.updateApiary(id, request);
      // Without this, getCachedApiary keeps returning the pre-edit response,
      // and ApiaryDetailsCubit.refreshFromCache (fired by the same
      // refreshNotifier.notify() this update triggers) clobbers the just-set
      // edited state with that stale cache read.
      await localDataSource.modify(
        (current) => [
          for (final existing in current ?? const <ApiaryResponse>[])
            if (existing.id != id) existing,
          response,
        ],
      );
      return response.toEntity();
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _updateOffline(id: id, name: name, description: description, location: location, lat: lat, lon: lon);
    }, (apiary) => Future.value(Right(apiary)));
  }

  /// Links [mediaId] (already uploaded to media-service, but not yet
  /// attached to anything) to [apiaryId] by fetching the apiary's current
  /// state, merging the id into its `images`, and PUTting it back - the
  /// only way to attach media now that media-service's own `attach`
  /// endpoint is internal-only (see `MediaRepositoryImpl.attachMedia`,
  /// the sole caller of this method via `IOwnerImageWriter`).
  ///
  /// Goes offline whenever [apiaryId] or [mediaId] is still a local,
  /// not-yet-synced placeholder, or there's already a pending operation for
  /// this apiary, or there's no connectivity - the same conservative rule
  /// [updateApiary] applies, for the same reason: this can't safely fetch
  /// "the current state" of an apiary the server doesn't know about yet, or
  /// reference a media id it hasn't heard of yet.
  @override
  Future<Either<Failure, MediaSyncStatus>> addApiaryImage({required String apiaryId, required String mediaId}) async {
    final pending = await _pendingOperationFor(apiaryId);
    if (pending != null || LocalIdGenerator.isLocal(apiaryId) || LocalIdGenerator.isLocal(mediaId) || !await connectivity.isOnline) {
      return _queueImageAdd(apiaryId: apiaryId, mediaId: mediaId);
    }

    final result = await on(() async {
      final current = await dataSource.getApiary(apiaryId);
      final request = ApiaryRequest(
        name: current.name,
        description: current.description,
        location: current.location,
        lat: current.lat,
        lon: current.lon,
        images: {...current.images, mediaId}.toList(),
      );
      final updated = await dataSource.updateApiary(apiaryId, request);
      await localDataSource.modify(
        (list) => [for (final existing in list ?? const <ApiaryResponse>[]) if (existing.id != apiaryId) existing, updated],
      );
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _queueImageAdd(apiaryId: apiaryId, mediaId: mediaId);
    }, (_) => Future.value(const Right(MediaSyncStatus.synced)));
  }

  Future<Either<Failure, MediaSyncStatus>> _queueImageAdd({required String apiaryId, required String mediaId}) async {
    final now = DateTime.now();
    final dependsOnOperationId = LocalIdGenerator.isLocal(mediaId) ? await _pendingMediaCreateOperationId(mediaId) : null;
    if (LocalIdGenerator.isLocal(mediaId) && dependsOnOperationId == null) {
      // Invariant violated: a local media id should always have a pending
      // upload operation behind it (see `MediaRepositoryImpl._attachOffline`).
      return const Left(InternalFailure(ErrorTextKey('core.errors.unexpected_network_error')));
    }
    await operationQueue.enqueue(
      OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: _apiaryEntityType,
        operationType: OperationType.imageAdd,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: apiaryId,
        dependsOnOperationId: dependsOnOperationId,
      ),
    );
    return const Right(MediaSyncStatus.pending);
  }

  /// The still-pending (or already-processed but not-yet-synced) `create`
  /// operation's id for the media identified by the local id [mediaId] -
  /// `null` if none is found.
  Future<String?> _pendingMediaCreateOperationId(String mediaId) async {
    final operations = await operationQueue.all();
    for (final operation in operations) {
      if (operation.entityType == mediaOperationEntityType &&
          operation.localEntityId == mediaId &&
          operation.operationType == OperationType.create) {
        return operation.id;
      }
    }
    return null;
  }

  /// A never-synced local entity is always deletable, online or off — there's
  /// nothing server-side to reconcile, so this just drops its placeholder and
  /// cancels its pending `CREATE` operation. A synced entity requires live
  /// connectivity to delete (surfaced in the UI as a hidden delete button
  /// with an explanatory note — see `_ApiaryDeleteLink`), since deleting it
  /// is a real server call with no offline-queued equivalent.
  @override
  Future<Either<Failure, void>> deleteApiary(String id) async {
    if (LocalIdGenerator.isLocal(id)) {
      return _deleteLocalOnly(id);
    }
    if (!await connectivity.isOnline) {
      return const Left(InternalFailure(ErrorTextKey('core.errors.delete_requires_connection')));
    }
    return _deleteOnline(id);
  }

  Future<Either<Failure, void>> _deleteLocalOnly(String id) async {
    await _purgeLocal(id);
    return const Right(null);
  }

  /// A 404 here means the server has already forgotten this entity — a
  /// stale local record left behind by, e.g., a previous sync that
  /// succeeded server-side but never reconciled locally, or a delete from
  /// another device/session. The desired end state (no such apiary) is
  /// already true, so this is treated as a successful delete rather than a
  /// failure — otherwise a row in this state could never be removed, since
  /// every retry would 404 the same way. See [on]'s `ignoreStatusCode`.
  Future<Either<Failure, void>> _deleteOnline(String id) async {
    final result = await on(() => dataSource.deleteApiary(id), ignoreStatusCode: 404, onIgnoredStatusCode: () {});

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
  Future<Either<Failure, Apiary>> _createOffline({
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  }) async {
    final now = DateTime.now();
    final localId = LocalIdGenerator.generate();
    final placeholder = ApiaryResponse(
      id: localId,
      name: name,
      description: description,
      location: location,
      lat: lat,
      lon: lon,
      createdAt: now,
      updatedAt: now,
    );
    await offlineMutationStore.saveWithPendingOperation<List<ApiaryResponse>>(
      cacheKey: apiaryCacheKey,
      mutate: (current) => [...(current ?? const []), placeholder],
      toJson: (list) => list.map((response) => response.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>).map((item) => ApiaryResponse.fromJson(item as Map<String, dynamic>)).toList(),
      operation: OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: _apiaryEntityType,
        operationType: OperationType.create,
        payload: ApiaryRequest(name: name, description: description, location: location, lat: lat, lon: lon).toJson(),
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: localId,
      ),
    );
    return Right(placeholder.toEntity().copyWith(syncStatus: ApiarySyncStatus.pending));
  }

  /// Updates the cached entity and folds the change into the single
  /// outstanding pending operation for [id] (see
  /// [OfflineMutationStore.saveWithConsolidatedOperation]) — a still-pending
  /// `CREATE` stays a `CREATE` with the newer payload; an already-synced
  /// entity gets a fresh `UPDATE` the first time, then that same `UPDATE` is
  /// reused (payload replaced, `version` bumped) on every further edit
  /// before it syncs. Returns immediately with the locally-held state, no
  /// network round trip needed.
  Future<Either<Failure, Apiary>> _updateOffline({
    required String id,
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  }) async {
    final now = DateTime.now();
    final request = ApiaryRequest(name: name, description: description, location: location, lat: lat, lon: lon);
    ApiaryResponse? updatedResponse;

    await offlineMutationStore.saveWithConsolidatedOperation<List<ApiaryResponse>>(
      cacheKey: apiaryCacheKey,
      mutate: (current) {
        final list = current ?? const <ApiaryResponse>[];
        ApiaryResponse? match;
        for (final response in list) {
          if (response.id == id) {
            match = response;
            break;
          }
        }
        // images: match?.images preserves whatever was last known to be
        // attached - this request never carries a value for it (see
        // [ApiaryRequest.images]), so without this, a plain field edit
        // would wipe the cached images list rather than leaving it alone.
        final response = request.toResponse(id: id, createdAt: match?.createdAt ?? now, updatedAt: now, images: match?.images ?? const []);
        updatedResponse = response;
        return [
          for (final existing in list)
            if (existing.id != id) existing,
          response,
        ];
      },
      toJson: (list) => list.map((response) => response.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>).map((item) => ApiaryResponse.fromJson(item as Map<String, dynamic>)).toList(),
      entityType: _apiaryEntityType,
      entityId: id,
      // Never the outstanding pending operation this looks up: an
      // `imageAdd` op tied to this same apiary (see
      // `ApiaryOperationHandler`) has its own dependency and identity that
      // this plain field edit must not clobber.
      matchingOperationTypes: const {OperationType.create, OperationType.update},
      operation: () => OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: _apiaryEntityType,
        operationType: OperationType.update,
        payload: request.toJson(),
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: id,
      ),
      mergeInto: (existing) => existing.copyWith(
        payload: request.toJson(),
        status: OperationStatus.pending,
        updatedAt: now,
        version: existing.version + 1,
      ),
    );

    return Right(updatedResponse!.toEntity().copyWith(syncStatus: ApiarySyncStatus.pending));
  }

  /// Includes both this apiary's own operations and every queued photo
  /// (`media`) operation, regardless of owner — [ApiaryCacheMerger] is the
  /// one that cross-references a photo operation's owner id against a given
  /// apiary id (see [combinedOperationStatus]), so a photo added offline
  /// marks its owning apiary's tile "needs sync" too.
  Future<List<OfflineOperation>> _apiaryOperations() async {
    return (await operationQueue.all())
        .where((operation) => operation.entityType == _apiaryEntityType || operation.entityType == mediaOperationEntityType)
        .toList();
  }

  /// The current non-synced operation for [id] (a pending `CREATE` if [id]
  /// is still local, or a pending/failed `UPDATE` if it's a synced entity
  /// with an unsynced edit) — `null` if [id] has nothing outstanding.
  Future<OfflineOperation?> _pendingOperationFor(String id) async {
    final matches = (await _apiaryOperations()).where(
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
  Future<Either<Failure, Page<Apiary>>> _cachedPageOrFailure(Failure failure, List<OfflineOperation> pendingOps) async {
    final cached = await localDataSource.read();
    if (cached == null || cached.isEmpty) {
      return Left(failure);
    }
    return Right(Page(items: cacheMerger.toEntities(cached, pendingOps), hasNext: false));
  }
}
