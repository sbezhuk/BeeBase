import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
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
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/utils/media_file_extension.dart';
import 'package:easy_localization/easy_localization.dart';

/// Executes a queued `media` operation when the [SyncEngine] drains the
/// queue. Simpler than `ApiaryOperationHandler`/`HiveOperationHandler`: a
/// photo is only ever created or removed, never edited, so there's no
/// version/supersede handling to do.
final class MediaOperationHandler extends Repository implements OperationHandler {
  MediaOperationHandler({
    required this.dataSource,
    required this.localDataSource,
    required this.localMediaStore,
    required this.operationQueue,
    required this.apiaryRefreshNotifier,
    required this.hiveRefreshNotifier,
  });

  final IMediaDataSource dataSource;
  final LocalDataSource<List<MediaResponse>> localDataSource;
  final LocalMediaStore localMediaStore;
  final OperationQueue operationQueue;
  final ApiaryListRefreshNotifier apiaryRefreshNotifier;
  final HiveListRefreshNotifier hiveRefreshNotifier;

  @override
  String get entityType => 'media';

  @override
  Future<OperationResult> handle(OfflineOperation operation) {
    return switch (operation.operationType) {
      OperationType.create => _handleCreate(operation),
      OperationType.update => Future.value(OperationPermanentFailure('media.errors.update_not_supported'.tr())),
      OperationType.delete => Future.value(OperationPermanentFailure('media.errors.offline_delete_not_supported'.tr())),
    };
  }

  Future<OperationResult> _handleCreate(OfflineOperation operation) async {
    final request = MediaUploadRequest.fromJson(operation.payload);
    final ownerId = await _resolveOwnerId(request.ownerId, operation.dependsOnOperationId);
    if (ownerId == null) {
      return OperationRetryableFailure('media.errors.owner_not_synced'.tr());
    }

    final result = await on(
      () => dataSource.uploadMedia(
        ownerType: request.ownerType,
        ownerId: ownerId,
        filePath: request.localFilePath,
        originalFilename: request.originalFilename,
        contentType: request.contentType,
        idempotencyKey: request.idempotencyKey,
      ),
    );

    return result.fold(_classify, (response) async {
      // Adopts (renames) the already-on-disk staged file onto the
      // deterministic cache path for the server's real id, rather than
      // deleting it — so this photo stays available offline immediately
      // after syncing instead of needing a redundant re-download the next
      // time it's displayed (see `MediaGalleryEmitter.resolveItemDisplayPath`).
      final cachedPath = await localMediaStore.adopt(
        request.localFilePath,
        id: response.id,
        extension: extensionFromFilename(request.originalFilename),
      );
      await _reconcileCache(operation.localEntityId, response, cachedPath);
      await _markSynced(operation, resolvedEntityId: response.id);
      _notifyOwnerListChanged(request.ownerType);
      return OperationSuccess(resolvedEntityId: response.id);
    });
  }

  /// Marks [operation] `synced` in the queue before the owner's list-refresh
  /// notifier fires. [SyncEngine] makes this exact same write itself once
  /// `handle()` returns (see `SyncEngineImpl._process`), but only *after*
  /// the handler call completes — which is too late for a gallery refresh
  /// triggered by `_notifyOwnerListChanged` below: it would still find this
  /// operation `inProgress` in the queue and keep showing a "needs
  /// synchronization" badge for a photo that has, in fact, already synced
  /// (see the identical fix in `ApiaryOperationHandler._markSynced`).
  /// `SyncEngineImpl`'s later write just repeats this (harmlessly) with a
  /// fresher `updatedAt` once it re-reads the row.
  Future<void> _markSynced(OfflineOperation operation, {String? resolvedEntityId}) {
    return operationQueue.update(
      operation.copyWith(status: OperationStatus.synced, resolvedEntityId: resolvedEntityId, updatedAt: DateTime.now()),
    );
  }

  /// Reuses the owning Apiary/Hive's list-refresh broadcast as the "media
  /// changed for this owner" signal — the same one `MediaGalleryCubit`
  /// already listens to for foreground add/remove calls (see
  /// `di.dart`'s `ownerListChanges` wiring), so a gallery left open while
  /// this operation was queued picks up the now-synced attachment too.
  void _notifyOwnerListChanged(MediaOwnerType ownerType) {
    switch (ownerType) {
      case MediaOwnerType.apiary:
        apiaryRefreshNotifier.notify();
      case MediaOwnerType.hive:
        hiveRefreshNotifier.notify();
    }
  }

  /// Resolves the owner id to actually send with a queued create. Most of
  /// the time [rawOwnerId] is already a real backend id and is returned
  /// as-is. When the photo was attached to an apiary/hive that was itself
  /// still a local placeholder, the real id has to be read off that owner's
  /// own now-synced operation — see
  /// `HiveOperationHandler._resolveApiaryId` for the identical pattern.
  Future<String?> _resolveOwnerId(String rawOwnerId, String? dependsOnOperationId) async {
    if (!LocalIdGenerator.isLocal(rawOwnerId)) {
      return rawOwnerId;
    }
    if (dependsOnOperationId == null) {
      return null;
    }
    final dependency = await operationQueue.find(dependsOnOperationId);
    return dependency?.resolvedEntityId;
  }

  Future<OperationResult> _classify(Failure failure) async {
    return failure is ServerFailure
        ? OperationPermanentFailure(failure.message.resolve())
        : OperationRetryableFailure(failure.message.resolve());
  }

  Future<void> _reconcileCache(String? localEntityId, MediaResponse serverResponse, String? cachedPath) {
    return localDataSource.modify((current) {
      final withoutPlaceholder = (current ?? const []).where((response) => response.id != localEntityId);
      return [...withoutPlaceholder, serverResponse.copyWith(localFilePath: cachedPath)];
    });
  }
}
