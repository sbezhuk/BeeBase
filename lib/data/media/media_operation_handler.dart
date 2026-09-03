import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_handler.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/models/media_upload_request.dart';
import 'package:beebase/data/repositories/owner_operation_status.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/media_file_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// Executes a queued `media` operation when the [SyncEngine] drains the
/// queue. Uploading and deleting a file are both owner-less as far as
/// media-service is concerned — linking an uploaded id to an Apiary/Hive
/// (or noticing a delete affects one) is `ApiaryOperationHandler`'s/
/// `HiveOperationHandler`'s job (`OperationType.imageAdd`), not this one's.
/// Simpler than those two: a photo is only ever created or removed, never
/// edited, so there's no version/supersede handling to do.
final class MediaOperationHandler extends Repository
    implements OperationHandler {
  MediaOperationHandler({
    required this.dataSource,
    required this.localDataSource,
    required this.localMediaStore,
    required this.operationQueue,
  });

  final IMediaDataSource dataSource;
  final LocalDataSource<List<MediaResponse>> localDataSource;
  final LocalMediaStore localMediaStore;
  final OperationQueue operationQueue;

  @override
  String get entityType => mediaOperationEntityType;

  @override
  Future<OperationResult> handle(OfflineOperation operation) {
    return switch (operation.operationType) {
      OperationType.create => _handleCreate(operation),
      OperationType.delete => _handleDelete(operation),
      OperationType.update => Future.value(
        OperationPermanentFailure('media.errors.update_not_supported'.tr()),
      ),
      // Only apiary/hive operations are ever queued as imageAdd - a media
      // operation reaching this branch would be a bug elsewhere.
      OperationType.imageAdd => Future.value(
        const OperationPermanentFailure('imageAdd is not a media operation.'),
      ),
    };
  }

  Future<OperationResult> _handleCreate(OfflineOperation operation) async {
    final request = MediaUploadRequest.fromJson(operation.payload);

    // Keyed by the request's stable idempotency key so a retried sync never
    // creates a second file server-side.
    debugPrint(
      '[MediaOperationHandler] ${_label(operation)} API request starting: upload ${request.originalFilename}.',
    );
    final result = await on(
      () => dataSource.uploadMedia(
        filePath: request.localFilePath,
        originalFilename: request.originalFilename,
        contentType: request.contentType,
        idempotencyKey: request.idempotencyKey,
      ),
      label: _label(operation),
    );

    return result.fold(_classify, (uploadedId) async {
      debugPrint(
        '[MediaOperationHandler] ${_label(operation)} API response received: uploaded id=$uploadedId.',
      );
      // Adopts (renames) the already-on-disk staged file onto the
      // deterministic cache path for the server's real id, rather than
      // deleting it — so this photo stays available offline immediately
      // after syncing instead of needing a redundant re-download the next
      // time it's displayed (see `MediaGalleryEmitter.resolveItemDisplayPath`).
      final cachedPath = await localMediaStore.adopt(
        request.localFilePath,
        id: uploadedId,
        extension: extensionFromFilename(request.originalFilename),
      );
      await _reconcileCache(operation.localEntityId, uploadedId, cachedPath);
      debugPrint(
        '[MediaOperationHandler] ${_label(operation)} local cache updated with the synced media ($uploadedId).',
      );
      await _markSynced(operation, resolvedEntityId: uploadedId);
      debugPrint(
        '[MediaOperationHandler] ${_label(operation)} sync status updated: pending/in-progress -> synced.',
      );
      return OperationSuccess(resolvedEntityId: uploadedId);
    });
  }

  /// A 404 here means the server has already forgotten this photo — treated
  /// as an already-completed delete, matching `MediaRepositoryImpl`'s policy
  /// for the same case online. See [on]'s `ignoreStatusCode`.
  Future<OperationResult> _handleDelete(OfflineOperation operation) async {
    final id = operation.localEntityId;
    if (id == null) {
      return const OperationPermanentFailure('Missing target id for delete.');
    }
    debugPrint(
      '[MediaOperationHandler] ${_label(operation)} API request starting: delete media $id.',
    );
    final result = await on(
      () => dataSource.deleteMedia(id),
      ignoreStatusCode: 404,
      onIgnoredStatusCode: () {},
      label: _label(operation),
    );

    return result.fold(_classify, (_) async {
      debugPrint(
        '[MediaOperationHandler] ${_label(operation)} API response received: $id deleted.',
      );
      await _markSynced(operation);
      debugPrint(
        '[MediaOperationHandler] ${_label(operation)} sync status updated: pending/in-progress -> synced.',
      );
      return const OperationSuccess();
    });
  }

  /// Marks [operation] `synced` in the queue before [SyncEngine] would
  /// otherwise get to it. [SyncEngine] makes this exact same write itself
  /// once `handle()` returns (see `SyncEngineImpl._process`), but only
  /// *after* the handler call completes — which is too late for a gallery
  /// refresh that might race ahead of it. `SyncEngineImpl`'s later write
  /// just repeats this (harmlessly) with a fresher `updatedAt` once it
  /// re-reads the row.
  Future<void> _markSynced(
    OfflineOperation operation, {
    String? resolvedEntityId,
  }) {
    return operationQueue.update(
      operation.copyWith(
        status: OperationStatus.synced,
        resolvedEntityId: resolvedEntityId,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<OperationResult> _classify(Failure failure) async {
    debugPrint(
      '[MediaOperationHandler] API request failed before a response could be used: $failure',
    );
    return failure is ServerFailure
        ? OperationPermanentFailure(failure.message.resolve())
        : OperationRetryableFailure(failure.message.resolve());
  }

  String _label(OfflineOperation operation) =>
      'media/${operation.operationType} (id=${operation.id})';

  /// Replaces the local placeholder (keyed by [localEntityId]) with the
  /// uploaded id, preserving whatever filename/size the placeholder was
  /// created with — the upload call itself doesn't return any of that, so
  /// this is the only place those values are known. A missing placeholder
  /// (cache cleared out from under a pending operation) is a no-op: the
  /// upload still succeeded server-side, and the next `getMedia` fetch
  /// will pick it up once it's actually referenced by an apiary/hive.
  Future<void> _reconcileCache(
    String? localEntityId,
    String uploadedId,
    String? cachedPath,
  ) {
    return localDataSource.modify((current) {
      final list = current ?? const <MediaResponse>[];
      MediaResponse? placeholder;
      for (final response in list) {
        if (response.id == localEntityId) {
          placeholder = response;
          break;
        }
      }
      if (placeholder == null) {
        return list;
      }
      final resolved = MediaResponse(
        id: uploadedId,
        originalFilename: placeholder.originalFilename,
        contentType: placeholder.contentType,
        sizeBytes: placeholder.sizeBytes,
        createdAt: placeholder.createdAt,
        updatedAt: DateTime.now(),
        localFilePath: cachedPath,
      );
      return [
        for (final response in list)
          if (response.id != localEntityId) response,
        resolved,
      ];
    });
  }
}
