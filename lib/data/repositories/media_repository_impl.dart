import 'dart:io';

import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/idempotency_key_generator.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_mutation_store.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/extensions/media_extension.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/models/media_upload_request.dart';
import 'package:beebase/data/repositories/media_cache_merger.dart';
import 'package:beebase/data/repositories/owner_operation_status.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/domain/repositories/owner_image_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';

/// Cache key both this repository and its DI registration of
/// `LocalDataSource<List<MediaResponse>>` agree on. One global cache holds
/// media across every owner — see [MediaCacheMerger]/[getMedia] for how
/// reads are filtered back down to just the currently-requested ids.
const mediaCacheKey = 'cached_media';

final class MediaRepositoryImpl extends Repository
    implements IMediaReader, IMediaWriter {
  MediaRepositoryImpl({
    required this.dataSource,
    required this.localDataSource,
    required this.localMediaStore,
    required this.connectivity,
    required this.operationQueue,
    required this.offlineMutationStore,
    required this.ownerImageWriter,
    this.cacheMerger = const MediaCacheMerger(),
  });

  final IMediaDataSource dataSource;
  final LocalDataSource<List<MediaResponse>> localDataSource;
  final LocalMediaStore localMediaStore;
  final IConnectivityService connectivity;
  final OperationQueue operationQueue;
  final OfflineMutationStore offlineMutationStore;

  /// Where linking an uploaded id to an owner actually happens now that
  /// media-service's own attach endpoint is internal-only - see
  /// [attachMedia].
  final IOwnerImageWriter ownerImageWriter;
  final MediaCacheMerger cacheMerger;

  /// Some of [ids] may themselves still be local, not-yet-synced placeholders
  /// (a photo picked while offline, or before its owner's own `create` has
  /// synced — see `MediaGalleryEmitter._attachOffline`/[attachMedia]). There
  /// is nothing the server can tell us about an id it has never seen — worse,
  /// sending it anyway gets rejected outright (a `ServerFailure`), which
  /// without this split would surface as a hard error and wipe out an
  /// otherwise-perfectly-good, already-visible local photo. So every local id
  /// is served from the cache only; only the real/synced ids are ever sent to
  /// the server, and their response gets merged back into the cache.
  ///
  /// media-service's `GET /api/v1/media` has no pagination of its own
  /// anymore — the response is always the complete answer for [ids], never a
  /// page — so this returns a plain list rather than a [Page].
  @override
  Future<Either<Failure, List<MediaAttachment>>> getMedia({
    required List<String> ids,
  }) async {
    if (ids.isEmpty) {
      return const Right([]);
    }

    final pendingOps = await _mediaOperations();
    final remoteIds = ids.where((id) => !LocalIdGenerator.isLocal(id)).toList();

    if (remoteIds.isEmpty) {
      return _cachedForIdsOrEmpty(ids, pendingOps);
    }

    if (!await connectivity.isOnline) {
      return _cachedForIdsOrFailure(
        ids,
        const InternalFailure(
          ErrorTextKey('core.errors.unexpected_network_error'),
        ),
        pendingOps,
      );
    }

    final result = await on(() async {
      final items = await dataSource.listMedia(ids: remoteIds);
      late List<MediaResponse> merged;
      await localDataSource.modify((current) {
        merged = cacheMerger.mergeForIds(
          items,
          current ?? const [],
          ids: ids.toSet(),
          pendingOps: pendingOps,
        );
        return merged;
      });
      return merged;
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _cachedForIdsOrFailure(ids, failure, pendingOps);
    }, (merged) async => Right(_orderedEntities(merged, ids, pendingOps)));
  }

  @override
  Future<Either<Failure, List<int>>> downloadMedia(String id) {
    return on(() => dataSource.downloadMedia(id));
  }

  @override
  Future<void> cacheDownloadedMedia(String id, String localFilePath) {
    return localDataSource.modify((current) {
      final list = current ?? const <MediaResponse>[];
      return [
        for (final response in list)
          if (response.id == id)
            response.copyWith(localFilePath: localFilePath)
          else
            response,
      ];
    });
  }

  /// Mirrors [getMedia]'s owner-id resolution: [ownerId] may still be a
  /// local placeholder. Unlike the old media-service-`attach` design, the
  /// *upload* half no longer cares — uploading bytes never needed an owner
  /// — so it always runs live when online, regardless of whether [ownerId]
  /// has synced yet. Only the *link* half ([ownerImageWriter]) needs a real
  /// owner id to PUT against, and it already handles a still-local one by
  /// queueing its own operation, exactly like it handles no connectivity.
  /// Once the owner *has* synced, that link goes out under its real,
  /// resolved id instead of the stale one the caller passed in.
  @override
  Future<Either<Failure, MediaAttachment>> attachMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String localFilePath,
    required String originalFilename,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final resolvedOwnerId = LocalIdGenerator.isLocal(ownerId)
        ? await _resolvedOwnerIdIfSynced(ownerType, ownerId)
        : null;
    final effectiveOwnerId = resolvedOwnerId ?? ownerId;

    if (!await connectivity.isOnline) {
      return _attachOffline(
        ownerType: ownerType,
        ownerId: ownerId,
        localFilePath: localFilePath,
        originalFilename: originalFilename,
        contentType: contentType,
      );
    }

    final result = await on(() async {
      // Upload (owner-less, keyed by a stable client-generated media_id so
      // a retried call never creates a second file) then link to the
      // owner via [ownerImageWriter] — media-service has no attach
      // endpoint a client can call directly anymore, so "attach" is now
      // apiary-service's/hive-service's job (see [IOwnerImageWriter]).
      // `effectiveOwnerId` may still be local here (if [ownerId]'s own
      // owner hasn't synced yet) - [ownerImageWriter] handles that exactly
      // like it handles no connectivity, queueing its own operation.
      final uploadedId = await dataSource.uploadMedia(
        filePath: localFilePath,
        originalFilename: originalFilename,
        contentType: contentType,
        idempotencyKey: IdempotencyKeyGenerator.generate(),
        onSendProgress: onProgress == null
            ? null
            : (sent, total) => onProgress(total <= 0 ? 0 : sent / total),
      );
      final now = DateTime.now();
      final placeholder = MediaResponse(
        id: uploadedId,
        originalFilename: originalFilename,
        contentType: contentType,
        sizeBytes: await File(localFilePath).length(),
        createdAt: now,
        updatedAt: now,
        localFilePath: localFilePath,
      );
      await localDataSource.modify(
        (current) => [...(current ?? const []), placeholder],
      );
      return placeholder;
    });

    return result.fold(
      (failure) async {
        if (failure is ServerFailure) {
          return Left(failure);
        }
        return _attachOffline(
          ownerType: ownerType,
          ownerId: ownerId,
          localFilePath: localFilePath,
          originalFilename: originalFilename,
          contentType: contentType,
        );
      },
      (placeholder) async {
        final addResult = await ownerImageWriter.addImage(
          ownerType: ownerType,
          ownerId: effectiveOwnerId,
          mediaId: placeholder.id,
        );
        return addResult.fold(
          Left.new,
          (syncStatus) => Future.value(
            Right(placeholder.toEntity().copyWith(syncStatus: syncStatus)),
          ),
        );
      },
    );
  }

  /// A never-synced local id is always removable, online or off — there's
  /// nothing server-side to reconcile, so this just drops its placeholder,
  /// cancels its pending `CREATE` operation, and deletes its local file. A
  /// synced photo can now be removed offline too (unlike Apiary/Hive, which
  /// still require connectivity to delete): `DELETE /media/{id}` is
  /// unaffected by `attach` moving internal-only, and queueing it is no
  /// riskier than any other queued operation - see [_deleteOffline].
  /// [ownerType]/[ownerId] are only actually used by the online path (see
  /// [_deleteOnline]) - [_deleteOffline] can't safely fetch-then-PUT an
  /// owner it has no connectivity to reach, so a removal made offline still
  /// risks leaving a stale reference behind until this gets revisited (see
  /// [_deleteOffline]'s own doc).
  @override
  Future<Either<Failure, void>> removeMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String id,
  }) async {
    if (LocalIdGenerator.isLocal(id)) {
      return _deleteLocalOnly(id);
    }
    if (!await connectivity.isOnline) {
      return _deleteOffline(id);
    }
    final result = await _deleteOnline(ownerType, ownerId, id);
    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _deleteOffline(id);
    }, (_) => Future.value(const Right(null)));
  }

  Future<Either<Failure, void>> _deleteLocalOnly(String id) async {
    await _purgeLocal(id);
    return const Right(null);
  }

  /// Detaches [id] from its owner's `images` *before* hard-deleting the
  /// file, in that order deliberately: apiary-service/hive-service validate
  /// every id in `images` against media-service on every `PUT`, so a photo
  /// deleted first and detached second (or not at all) leaves the owner
  /// referencing a now-nonexistent id — which then rejects the *next*
  /// unrelated `addApiaryImage`/`addHiveImage` call for that same owner
  /// with `image_not_found`, silently blocking every future photo add to
  /// it. Detaching first means a failed detach simply fails the whole
  /// remove (surfaced to the user as a retryable error) rather than ever
  /// reaching that broken state. A 404 from the delete itself still means
  /// an already-completed delete — matching `ApiaryRepositoryImpl`'s policy
  /// for the same case. See [on]'s `ignoreStatusCode`.
  Future<Either<Failure, void>> _deleteOnline(
    MediaOwnerType ownerType,
    String ownerId,
    String id,
  ) async {
    final detachResult = await ownerImageWriter.removeImage(
      ownerType: ownerType,
      ownerId: ownerId,
      mediaId: id,
    );

    return detachResult.fold(Left.new, (_) async {
      final result = await on(
        () => dataSource.deleteMedia(id),
        ignoreStatusCode: 404,
        onIgnoredStatusCode: () {},
      );

      return result.fold((failure) async => Left(failure), (_) async {
        await _purgeLocal(id);
        return const Right(null);
      });
    });
  }

  /// Removes [id] from the cache immediately (optimistic - it's already
  /// gone from any open gallery's view, so there's no risk of it
  /// reappearing from a cache-driven merge before the queued delete
  /// actually runs) and queues a `media` `delete` operation for
  /// `MediaOperationHandler` to replay once online. Unlike a pending photo
  /// *add* (which marks its owning apiary/hive tile "pending sync" via
  /// that entity's own queued `imageAdd` operation, keyed by the
  /// apiary/hive's own id - see `combinedOperationStatus`), a pending
  /// delete carries no owner id in its payload: media-service's response
  /// no longer carries one to source it from, and `DELETE /media/{id}`
  /// itself doesn't need one either. The owning tile simply won't show
  /// "pending sync" for the brief window a queued delete is in flight.
  Future<Either<Failure, void>> _deleteOffline(String id) async {
    final now = DateTime.now();
    await localDataSource.modify((current) {
      final list = current ?? const <MediaResponse>[];
      return list.where((response) => response.id != id).toList();
    });
    await operationQueue.enqueue(
      OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: mediaOperationEntityType,
        operationType: OperationType.delete,
        payload: const {},
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: id,
      ),
    );
    return const Right(null);
  }

  /// Drops [id]'s cache entry, its lingering pending operation (if any), and
  /// its on-disk local file (if any). Also cancels any operation still
  /// depending on that one (an `imageAdd` op waiting on this exact photo's
  /// upload - see `ApiaryRepositoryImpl`/`HiveRepositoryImpl.
  /// _queueImageAdd`) - left behind, it would sit gated on a dependency
  /// that no longer exists and never run or fail, forever.
  Future<void> _purgeLocal(String id) async {
    String? localFilePath;
    await localDataSource.modify((current) {
      final list = current ?? const <MediaResponse>[];
      for (final response in list) {
        if (response.id == id) {
          localFilePath = response.localFilePath;
          break;
        }
      }
      return list.where((response) => response.id != id).toList();
    });
    final path = localFilePath;
    if (path != null) {
      await localMediaStore.delete(path);
    }
    final pending = await _pendingOperationFor(id);
    if (pending != null) {
      await operationQueue.remove(pending.id);
      final dependents = (await operationQueue.all()).where(
        (op) => op.dependsOnOperationId == pending.id,
      );
      for (final dependent in dependents) {
        await operationQueue.remove(dependent.id);
      }
    }
  }

  /// Saves the local placeholder and enqueues its upload operation
  /// atomically — never local-entity-without-operation or the reverse. The
  /// upload operation itself is owner-less and dependency-less (uploading
  /// bytes never needed an owner to exist) — linking it to [ownerId] is a
  /// second, separate step via [ownerImageWriter], queued right after: that
  /// call recognizes [localId] as a local, not-yet-uploaded media id and
  /// queues its own `imageAdd` operation depending on this one, rather than
  /// trying to send it anywhere.
  Future<Either<Failure, MediaAttachment>> _attachOffline({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String localFilePath,
    required String originalFilename,
    required String contentType,
  }) async {
    final now = DateTime.now();
    final localId = LocalIdGenerator.generate();
    final sizeBytes = await File(localFilePath).length();
    final placeholder = MediaResponse(
      id: localId,
      originalFilename: originalFilename,
      contentType: contentType,
      sizeBytes: sizeBytes,
      createdAt: now,
      updatedAt: now,
      localFilePath: localFilePath,
    );
    await offlineMutationStore.saveWithPendingOperation<List<MediaResponse>>(
      cacheKey: mediaCacheKey,
      mutate: (current) => [...(current ?? const []), placeholder],
      toJson: (list) => list.map((response) => response.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>)
          .map((item) => MediaResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
      operation: OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: mediaOperationEntityType,
        operationType: OperationType.create,
        payload: MediaUploadRequest(
          localFilePath: localFilePath,
          originalFilename: originalFilename,
          contentType: contentType,
          idempotencyKey: IdempotencyKeyGenerator.generate(),
        ).toJson(),
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: localId,
      ),
    );
    final addResult = await ownerImageWriter.addImage(
      ownerType: ownerType,
      ownerId: ownerId,
      mediaId: localId,
    );
    return addResult.fold(
      Left.new,
      (syncStatus) => Future.value(
        Right(placeholder.toEntity().copyWith(syncStatus: syncStatus)),
      ),
    );
  }

  /// The apiary/hive `create` operation for the owner identified by the
  /// local id [ownerId] — synced or not, `null` if none is found. Used by
  /// [_resolvedOwnerIdIfSynced].
  Future<OfflineOperation?> _ownerCreateOperation(
    MediaOwnerType ownerType,
    String ownerId,
  ) async {
    final expectedEntityType = ownerType == MediaOwnerType.apiary
        ? 'apiary'
        : 'hive';
    final operations = await operationQueue.all();
    for (final operation in operations) {
      if (operation.entityType == expectedEntityType &&
          operation.localEntityId == ownerId &&
          operation.operationType == OperationType.create) {
        return operation;
      }
    }
    return null;
  }

  /// The owner's real, server-assigned id once its own `create` operation
  /// has synced — `null` while it's still pending/failed (still local) or
  /// there's no such operation at all. Used by [getMedia]/[attachMedia] so a
  /// caller that's still holding a stale local owner id (a `MediaGalleryCubit`
  /// bound once at construction time, never rebuilt just because its owner
  /// synced) transparently starts talking to the server under the right id
  /// the moment that id exists, without needing to know it changed.
  Future<String?> _resolvedOwnerIdIfSynced(
    MediaOwnerType ownerType,
    String ownerId,
  ) async {
    final operation = await _ownerCreateOperation(ownerType, ownerId);
    return operation?.status == OperationStatus.synced
        ? operation?.resolvedEntityId
        : null;
  }

  Future<List<OfflineOperation>> _mediaOperations() async {
    return (await operationQueue.all())
        .where((operation) => operation.entityType == mediaOperationEntityType)
        .toList();
  }

  Future<OfflineOperation?> _pendingOperationFor(String id) async {
    final matches = (await _mediaOperations()).where(
      (operation) =>
          operation.localEntityId == id &&
          operation.status != OperationStatus.synced,
    );
    if (matches.isEmpty) {
      return null;
    }
    return matches.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
  }

  Future<Either<Failure, List<MediaAttachment>>> _cachedForIdsOrFailure(
    List<String> ids,
    Failure failure,
    List<OfflineOperation> pendingOps,
  ) async {
    final cached = await _cachedFor(ids);
    if (cached.isEmpty) {
      return Left(failure);
    }
    return Right(_orderedEntities(cached, ids, pendingOps));
  }

  /// Same cache lookup as [_cachedForIdsOrFailure], but for a request made up
  /// entirely of still-local, not-yet-synced ids: there is no server truth to
  /// fall back to failing over from, so the cache — even an empty one,
  /// meaning genuinely nothing cached yet — is treated as the complete answer
  /// rather than a failure.
  Future<Either<Failure, List<MediaAttachment>>> _cachedForIdsOrEmpty(
    List<String> ids,
    List<OfflineOperation> pendingOps,
  ) async {
    final cached = await _cachedFor(ids);
    return Right(_orderedEntities(cached, ids, pendingOps));
  }

  Future<List<MediaResponse>> _cachedFor(List<String> ids) async {
    final requested = ids.toSet();
    return ((await localDataSource.read()) ?? const [])
        .where((response) => requested.contains(response.id))
        .toList();
  }

  /// [responses] filtered down to just [ids] and reordered to match — the
  /// cache/merge result may hold rows for other owners too (it's one global
  /// cache, see [MediaCacheMerger]) and isn't guaranteed to already be in
  /// [ids]'s order.
  List<MediaAttachment> _orderedEntities(
    List<MediaResponse> responses,
    List<String> ids,
    List<OfflineOperation> pendingOps,
  ) {
    final byId = {for (final response in responses) response.id: response};
    final ordered = [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
    return cacheMerger.toEntities(ordered, pendingOps);
  }
}
