import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_handler.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/models/media_upload_request.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:easy_localization/easy_localization.dart';

/// Executes a queued `media` operation when the [SyncEngine] drains the
/// queue. Simpler than `ApiaryOperationHandler`/`HiveOperationHandler`: a
/// photo is only ever created or removed, never edited, so there's no
/// version/supersede handling to do.
final class MediaOperationHandler extends Repository
    implements OperationHandler {
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
      OperationType.update => Future.value(
        OperationPermanentFailure('media.errors.updateNotSupported'.tr()),
      ),
      OperationType.delete => Future.value(
        OperationPermanentFailure(
          'media.errors.offlineDeleteNotSupported'.tr(),
        ),
      ),
    };
  }

  Future<OperationResult> _handleCreate(OfflineOperation operation) async {
    final request = MediaUploadRequest.fromJson(operation.payload);
    final ownerId = await _resolveOwnerId(
      request.ownerId,
      operation.dependsOnOperationId,
    );
    if (ownerId == null) {
      return OperationRetryableFailure('media.errors.ownerNotSynced'.tr());
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
      await _reconcileCache(operation.localEntityId, response);
      await localMediaStore.delete(request.localFilePath);
      _notifyOwnerListChanged(request.ownerType);
      return OperationSuccess(resolvedEntityId: response.id);
    });
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
  Future<String?> _resolveOwnerId(
    String rawOwnerId,
    String? dependsOnOperationId,
  ) async {
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

  Future<void> _reconcileCache(
    String? localEntityId,
    MediaResponse serverResponse,
  ) {
    return localDataSource.modify((current) {
      final withoutPlaceholder = (current ?? const []).where(
        (response) => response.id != localEntityId,
      );
      return [...withoutPlaceholder, serverResponse];
    });
  }
}
