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
import 'package:beebase/data/models/extensions/user_extension.dart';
import 'package:beebase/data/models/profile_update_request.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/profile_reader.dart';
import 'package:beebase/domain/repositories/profile_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/media_file_extension.dart';
import 'package:path/path.dart' as p;

/// The `entityType` queued profile operations are filed under — matched by
/// `ProfileOperationHandler` via `OperationRegistry`.
const profileOperationEntityType = 'profile';

/// Must match the `key` this app registers `LocalDataSource<UserResponse>`
/// under in `di.dart` — the same cached-user entry `AuthenticationRepositoryImpl`
/// already reads/writes, since a profile update is just an edit to the
/// currently authenticated user.
const profileCacheKey = 'cached_user';

final class ProfileRepositoryImpl extends Repository
    implements IProfileReader, IProfileWriter {
  ProfileRepositoryImpl({
    required this.dataSource,
    required this.mediaDataSource,
    required this.localDataSource,
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
  final LocalDataSource<UserResponse> localDataSource;
  final IConnectivityService connectivity;
  final OperationQueue operationQueue;
  final OfflineMutationStore offlineMutationStore;

  @override
  Future<Either<Failure, User>> getProfile() async {
    if (!await connectivity.isOnline) {
      return _cachedProfileOrFailure();
    }

    final result = await on(() async {
      final response = await dataSource.getProfile();
      final cached = await localDataSource.read();
      final resolved = response.copyWith(
        avatarLocalFilePath: cached?.avatar == response.avatar
            ? cached?.avatarLocalFilePath
            : null,
      );
      await localDataSource.write(resolved);
      return resolved;
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _cachedProfileOrFailure(fallback: failure);
    }, (response) async => Right(response.toEntity()));
  }

  Future<Either<Failure, User>> _cachedProfileOrFailure({
    Failure? fallback,
  }) async {
    final cached = await localDataSource.read();
    if (cached == null) {
      return Left(
        fallback ??
            const InternalFailure(
              ErrorTextKey('core.errors.unexpected_network_error'),
            ),
      );
    }
    return Right(cached.toEntity());
  }

  @override
  Future<Either<Failure, User>> updateProfile({
    required String firstName,
    required String lastName,
    String? newAvatarLocalFilePath,
    bool removeAvatar = false,
  }) async {
    final cached = await localDataSource.read();
    if (cached == null) {
      return const Left(
        InternalFailure(ErrorTextKey('core.errors.no_active_session')),
      );
    }
    final pending = await _pendingOperation(cached.id);

    if (pending != null || !await connectivity.isOnline) {
      return _updateOffline(
        cached: cached,
        pending: pending,
        firstName: firstName,
        lastName: lastName,
        newAvatarLocalFilePath: newAvatarLocalFilePath,
        removeAvatar: removeAvatar,
      );
    }

    final result = await on(() async {
      final avatarId = removeAvatar
          ? null
          : newAvatarLocalFilePath != null
          ? await _uploadAvatar(newAvatarLocalFilePath)
          : cached.avatar;
      final response = await dataSource.updateProfile(
        ProfileUpdateRequest(
          firstName: firstName,
          lastName: lastName,
          avatar: avatarId,
        ),
      );
      final resolved = response.copyWith(
        avatarLocalFilePath:
            newAvatarLocalFilePath ?? cached.avatarLocalFilePath,
        clearAvatarLocalFilePath: removeAvatar,
      );
      await localDataSource.write(resolved);
      return resolved;
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _updateOffline(
        cached: cached,
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
      contentType: contentTypeFromExtension(
        extensionFromFilename(originalFilename),
      ),
      idempotencyKey: IdempotencyKeyGenerator.generate(),
    );
  }

  /// Saves the edit locally and consolidates it into the single outstanding
  /// pending `update` operation for this user (see
  /// `OfflineMutationStore.saveWithConsolidatedOperation`), so repeated
  /// offline edits never stack up as separate queued operations.
  ///
  /// A new avatar pick is given a local placeholder id (see
  /// [LocalIdGenerator]) so [User.avatarId] can be checked the same way
  /// every other locally-picked-but-unsynced media id is (`isLocal`) — the
  /// actual upload happens once `ProfileOperationHandler` replays this
  /// operation online. An edit that doesn't touch the avatar at all
  /// (`newAvatarLocalFilePath` and `removeAvatar` both unset) carries
  /// forward whatever avatar state [pending] already has queued, rather
  /// than [cached]'s — [cached] may itself already reflect an earlier,
  /// still-unsynced avatar pick from a previous call to this method.
  Future<Either<Failure, User>> _updateOffline({
    required UserResponse cached,
    required OfflineOperation? pending,
    required String firstName,
    required String lastName,
    String? newAvatarLocalFilePath,
    required bool removeAvatar,
  }) async {
    final now = DateTime.now();
    final payload = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
    };
    String? nextAvatarId;
    String? nextAvatarLocalFilePath;

    if (removeAvatar) {
      payload['avatar'] = null;
    } else if (newAvatarLocalFilePath != null) {
      nextAvatarId = LocalIdGenerator.generate();
      nextAvatarLocalFilePath = newAvatarLocalFilePath;
      payload['avatar_local_file_path'] = newAvatarLocalFilePath;
      payload['avatar_idempotency_key'] = IdempotencyKeyGenerator.generate();
    } else if (pending != null &&
        pending.payload['avatar_local_file_path'] != null) {
      nextAvatarId = cached.avatar;
      nextAvatarLocalFilePath = cached.avatarLocalFilePath;
      payload['avatar_local_file_path'] =
          pending.payload['avatar_local_file_path'];
      payload['avatar_idempotency_key'] =
          pending.payload['avatar_idempotency_key'];
    } else {
      nextAvatarId = cached.avatar;
      nextAvatarLocalFilePath = cached.avatarLocalFilePath;
      payload['avatar'] = cached.avatar;
    }

    UserResponse? updated;
    await offlineMutationStore.saveWithConsolidatedOperation<UserResponse>(
      cacheKey: profileCacheKey,
      mutate: (current) {
        final base = current ?? cached;
        final response = base.copyWith(
          firstName: firstName,
          lastName: lastName,
          avatar: nextAvatarId,
          clearAvatar: nextAvatarId == null,
          avatarLocalFilePath: nextAvatarLocalFilePath,
          clearAvatarLocalFilePath: nextAvatarLocalFilePath == null,
        );
        updated = response;
        return response;
      },
      toJson: (response) => response.toJson(),
      fromJson: (json) => UserResponse.fromJson(json as Map<String, dynamic>),
      entityType: profileOperationEntityType,
      entityId: cached.id,
      matchingOperationTypes: const {OperationType.update},
      operation: () => OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: profileOperationEntityType,
        operationType: OperationType.update,
        payload: payload,
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: cached.id,
      ),
      mergeInto: (existing) => existing.copyWith(
        payload: payload,
        status: OperationStatus.pending,
        updatedAt: now,
        version: existing.version + 1,
      ),
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
