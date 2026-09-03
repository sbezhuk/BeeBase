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
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/data_source/interface/profile_data_source.dart';
import 'package:beebase/data/models/extensions/profile_extension.dart';
import 'package:beebase/data/models/profile_response.dart';
import 'package:beebase/data/models/profile_update_request.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/domain/entity/profile.dart';
import 'package:beebase/domain/repositories/profile_reader.dart';
import 'package:beebase/domain/repositories/profile_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/media_file_extension.dart';
import 'package:path/path.dart' as p;

/// The `entityType` queued profile operations are filed under — matched by
/// `ProfileOperationHandler` via `OperationRegistry`.
const profileOperationEntityType = 'profile';

/// Must match the `key` this app registers `LocalDataSource<ProfileResponse>`
/// under in `di.dart`.
const profileCacheKey = 'cached_profile';

final class ProfileRepositoryImpl extends Repository implements IProfileReader, IProfileWriter {
  ProfileRepositoryImpl({
    required this.dataSource,
    required this.mediaDataSource,
    required this.userLocalDataSource,
    required this.profileLocalDataSource,
    required this.connectivity,
    required this.operationQueue,
    required this.offlineMutationStore,
  });

  final IProfileDataSource dataSource;

  /// Uploads a picked avatar's raw bytes. Deliberately the narrow media
  /// data source, not `IMediaWriter` — a profile's avatar is a single field
  /// on the user, not an entry in some owner's `images` list, so there is
  /// nothing to link it to via `IOwnerImageWriter` (see `MediaOwnerType`,
  /// which only knows about apiaries and hives). `PUT /api/v1/profile`
  /// itself carries the resulting media id.
  final IMediaDataSource mediaDataSource;

  /// Read-only here — the same `LocalDataSource<UserResponse>`
  /// `AuthenticationRepositoryImpl` writes to. auth-service's profile
  /// resource has no id of its own to source from until [getProfile] has
  /// run at least once; this is the fallback so an offline profile edit
  /// still knows which user it belongs to even before that first fetch.
  final LocalDataSource<UserResponse> userLocalDataSource;
  final LocalDataSource<ProfileResponse> profileLocalDataSource;
  final IConnectivityService connectivity;
  final OperationQueue operationQueue;
  final OfflineMutationStore offlineMutationStore;

  @override
  Future<Either<Failure, Profile>> getProfile() async {
    if (!await connectivity.isOnline) {
      return _cachedProfileOrFailure();
    }

    final result = await on(() async {
      final response = await dataSource.getProfile();
      final cached = await profileLocalDataSource.read();
      final resolved = response.copyWith(
        avatarLocalFilePath: cached?.avatar == response.avatar ? cached?.avatarLocalFilePath : null,
      );
      await profileLocalDataSource.write(resolved);
      return resolved;
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _cachedProfileOrFailure(fallback: failure);
    }, (response) async => Right(response.toEntity()));
  }

  Future<Either<Failure, Profile>> _cachedProfileOrFailure({Failure? fallback}) async {
    final cached = await profileLocalDataSource.read();
    if (cached == null) {
      return Left(fallback ?? const InternalFailure(ErrorTextKey('core.errors.unexpected_network_error')));
    }
    return Right(cached.toEntity());
  }

  @override
  Future<Either<Failure, Profile>> updateProfile({
    required String firstName,
    required String lastName,
    String? newAvatarLocalFilePath,
    bool removeAvatar = false,
  }) async {
    final userId = await _resolveUserId();
    if (userId == null) {
      return const Left(InternalFailure(ErrorTextKey('core.errors.no_active_session')));
    }
    final pending = await _pendingOperation(userId);

    if (pending != null || !await connectivity.isOnline) {
      return _updateOffline(
        userId: userId,
        pending: pending,
        firstName: firstName,
        lastName: lastName,
        newAvatarLocalFilePath: newAvatarLocalFilePath,
        removeAvatar: removeAvatar,
      );
    }

    final result = await on(() async {
      // Per auth-service's own contract: null/omitted leaves the current
      // avatar untouched, '' removes it, an id replaces it — never resend
      // the current id, there's no need to.
      final avatar = removeAvatar
          ? ''
          : newAvatarLocalFilePath != null
          ? await _uploadAvatar(newAvatarLocalFilePath)
          : null;
      final response = await dataSource.updateProfile(
        ProfileUpdateRequest(firstName: firstName, lastName: lastName, avatar: avatar),
      );
      final cached = await profileLocalDataSource.read();
      final resolved = response.copyWith(
        avatarLocalFilePath: newAvatarLocalFilePath ?? (removeAvatar ? null : cached?.avatarLocalFilePath),
        clearAvatarLocalFilePath: removeAvatar,
      );
      await profileLocalDataSource.write(resolved);
      return resolved;
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _updateOffline(
        userId: userId,
        pending: pending,
        firstName: firstName,
        lastName: lastName,
        newAvatarLocalFilePath: newAvatarLocalFilePath,
        removeAvatar: removeAvatar,
      );
    }, (response) => Future.value(Right(response.toEntity())));
  }

  Future<String> _uploadAvatar(String localFilePath) {
    final originalFilename = p.basename(localFilePath);
    return mediaDataSource.uploadMedia(
      filePath: localFilePath,
      originalFilename: originalFilename,
      contentType: contentTypeFromExtension(extensionFromFilename(originalFilename)),
      idempotencyKey: IdempotencyKeyGenerator.generate(),
    );
  }

  Future<String?> _resolveUserId() async {
    final cachedProfile = await profileLocalDataSource.read();
    if (cachedProfile != null) {
      return cachedProfile.id;
    }
    return (await userLocalDataSource.read())?.id;
  }

  /// Saves the edit locally and consolidates it into the single outstanding
  /// pending `update` operation for this user (see
  /// `OfflineMutationStore.saveWithConsolidatedOperation`), so repeated
  /// offline edits never stack up as separate queued operations.
  ///
  /// The avatar-related payload keys are omitted entirely when this edit
  /// doesn't touch the avatar and nothing was already pending — replaying
  /// the request with no `avatar` key leaves it untouched server-side, so
  /// there's nothing to carry forward. If something *is* already pending
  /// (an earlier, still-unsynced offline edit staged a pick or a removal),
  /// that gets carried forward instead — otherwise consolidating this
  /// plain field edit into the same operation would silently drop it.
  Future<Either<Failure, Profile>> _updateOffline({
    required String userId,
    required OfflineOperation? pending,
    required String firstName,
    required String lastName,
    String? newAvatarLocalFilePath,
    required bool removeAvatar,
  }) async {
    final now = DateTime.now();
    final payload = <String, dynamic>{'firstName': firstName, 'lastName': lastName};
    String? nextAvatarLocalFilePath;
    var clearAvatarLocalFilePath = false;

    if (removeAvatar) {
      payload['avatar'] = '';
      clearAvatarLocalFilePath = true;
    } else if (newAvatarLocalFilePath != null) {
      payload['avatarLocalFilePath'] = newAvatarLocalFilePath;
      payload['avatarIdempotencyKey'] = IdempotencyKeyGenerator.generate();
      nextAvatarLocalFilePath = newAvatarLocalFilePath;
    } else if (pending != null) {
      if (pending.payload.containsKey('avatar')) {
        payload['avatar'] = pending.payload['avatar'];
        clearAvatarLocalFilePath = true;
      } else if (pending.payload.containsKey('avatarLocalFilePath')) {
        payload['avatarLocalFilePath'] = pending.payload['avatarLocalFilePath'];
        payload['avatarIdempotencyKey'] = pending.payload['avatarIdempotencyKey'];
        nextAvatarLocalFilePath = pending.payload['avatarLocalFilePath'] as String?;
      }
    }

    ProfileResponse? updated;
    await offlineMutationStore.saveWithConsolidatedOperation<ProfileResponse>(
      cacheKey: profileCacheKey,
      mutate: (current) {
        final base =
            current ?? ProfileResponse(id: userId, email: '', firstName: firstName, lastName: lastName);
        final response = base.copyWith(
          firstName: firstName,
          lastName: lastName,
          clearAvatar: removeAvatar,
          avatarLocalFilePath: nextAvatarLocalFilePath,
          clearAvatarLocalFilePath: clearAvatarLocalFilePath,
        );
        updated = response;
        return response;
      },
      toJson: (response) => response.toJson(),
      fromJson: (json) => ProfileResponse.fromJson(json as Map<String, dynamic>),
      entityType: profileOperationEntityType,
      entityId: userId,
      matchingOperationTypes: const {OperationType.update},
      operation: () => OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: profileOperationEntityType,
        operationType: OperationType.update,
        payload: payload,
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: userId,
      ),
      mergeInto: (existing) =>
          existing.copyWith(payload: payload, status: OperationStatus.pending, updatedAt: now, version: existing.version + 1),
    );

    return Right(updated!.toEntity());
  }

  Future<OfflineOperation?> _pendingOperation(String userId) async {
    final matches = (await operationQueue.all()).where(
      (operation) =>
          operation.entityType == profileOperationEntityType &&
          operation.localEntityId == userId &&
          operation.status != OperationStatus.synced,
    );
    if (matches.isEmpty) {
      return null;
    }
    return matches.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
  }
}
