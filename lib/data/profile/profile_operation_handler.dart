import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_handler.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/data_source/interface/profile_data_source.dart';
import 'package:beebase/data/models/profile_update_request.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/data/repositories/profile_repository_impl.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/media_file_extension.dart';
import 'package:path/path.dart' as p;

/// Executes a queued `profile` operation when the [SyncEngine] drains the
/// queue. Only `update` is ever queued for this entity type — a profile is
/// never created or deleted client-side, and there is no per-field
/// `imageAdd` equivalent (an avatar pick simply travels inside the same
/// `update` payload — see `ProfileRepositoryImpl._updateOffline`).
final class ProfileOperationHandler extends Repository
    implements OperationHandler {
  ProfileOperationHandler({
    required this.dataSource,
    required this.mediaDataSource,
    required this.localDataSource,
    required this.operationQueue,
  });

  final IProfileDataSource dataSource;
  final IMediaDataSource mediaDataSource;
  final LocalDataSource<UserResponse> localDataSource;
  final OperationQueue operationQueue;

  @override
  String get entityType => profileOperationEntityType;

  @override
  Future<OperationResult> handle(OfflineOperation operation) {
    return switch (operation.operationType) {
      OperationType.update => _handleUpdate(operation),
      OperationType.create => Future.value(
        const OperationPermanentFailure('Profile create is not supported.'),
      ),
      OperationType.delete => Future.value(
        const OperationPermanentFailure('Profile delete is not supported.'),
      ),
      OperationType.imageAdd => Future.value(
        const OperationPermanentFailure('imageAdd is not a profile operation.'),
      ),
    };
  }

  Future<OperationResult> _handleUpdate(OfflineOperation operation) async {
    final userId = operation.localEntityId;
    if (userId == null) {
      return const OperationPermanentFailure('Missing target id for update.');
    }
    final payload = operation.payload;
    final pendingLocalPath = payload['avatar_local_file_path'] as String?;

    if (pendingLocalPath == null) {
      return _sendUpdate(
        operation,
        avatarId: payload['avatar'] as String?,
        pendingLocalPath: null,
      );
    }

    final idempotencyKey =
        payload['avatar_idempotency_key'] as String? ?? operation.id;
    final originalFilename = p.basename(pendingLocalPath);
    final uploadResult = await on(
      () => mediaDataSource.uploadMedia(
        filePath: pendingLocalPath,
        originalFilename: originalFilename,
        contentType: contentTypeFromExtension(
          extensionFromFilename(originalFilename),
        ),
        idempotencyKey: idempotencyKey,
      ),
    );

    return uploadResult.fold(
      _classify,
      (uploadedId) => _sendUpdate(
        operation,
        avatarId: uploadedId,
        pendingLocalPath: pendingLocalPath,
      ),
    );
  }

  Future<OperationResult> _sendUpdate(
    OfflineOperation operation, {
    required String? avatarId,
    required String? pendingLocalPath,
  }) async {
    final payload = operation.payload;
    final request = ProfileUpdateRequest(
      firstName: payload['first_name'] as String,
      lastName: payload['last_name'] as String,
      avatar: avatarId,
    );
    final result = await on(() => dataSource.updateProfile(request));

    return result.fold(_classify, (response) async {
      // A newer local edit was consolidated into this operation's row while
      // the request above was in flight — this response is already stale,
      // and the row already carries the newer payload for another sync pass.
      final current = await operationQueue.find(operation.id);
      if (current != null && current.version != operation.version) {
        return const OperationSuperseded();
      }

      final cached = await localDataSource.read();
      final resolved = response.copyWith(
        avatarLocalFilePath: pendingLocalPath ?? cached?.avatarLocalFilePath,
        clearAvatarLocalFilePath: avatarId == null,
      );
      await localDataSource.write(resolved);
      await _markSynced(operation, resolvedEntityId: avatarId);
      return const OperationSuccess();
    });
  }

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
    return failure is ServerFailure
        ? OperationPermanentFailure(failure.message.resolve())
        : OperationRetryableFailure(failure.message.resolve());
  }
}
