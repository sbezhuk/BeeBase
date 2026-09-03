import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/offline/offline_mutation_store.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/data_source/interface/profile_data_source.dart';
import 'package:beebase/data/models/profile_response.dart';
import 'package:beebase/data/models/profile_update_request.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/data/repositories/profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileDataSource extends Mock implements IProfileDataSource {}

class MockMediaDataSource extends Mock implements IMediaDataSource {}

class MockUserLocalDataSource extends Mock implements LocalDataSource<UserResponse> {}

class MockProfileLocalDataSource extends Mock implements LocalDataSource<ProfileResponse> {}

class MockConnectivityService extends Mock implements IConnectivityService {}

class MockOperationQueue extends Mock implements OperationQueue {}

class MockOfflineMutationStore extends Mock implements OfflineMutationStore {}

void main() {
  late MockProfileDataSource dataSource;
  late MockMediaDataSource mediaDataSource;
  late MockUserLocalDataSource userLocalDataSource;
  late MockProfileLocalDataSource profileLocalDataSource;
  late MockConnectivityService connectivity;
  late MockOperationQueue operationQueue;
  late MockOfflineMutationStore offlineMutationStore;
  late ProfileRepositoryImpl repository;

  final cachedProfile = ProfileResponse(
    id: 'user-1',
    email: 'john@example.com',
    firstName: 'John',
    lastName: 'Doe',
    avatar: 'media-1',
  );

  setUpAll(() {
    registerFallbackValue(const ProfileUpdateRequest(firstName: 'fallback', lastName: 'fallback'));
    registerFallbackValue(
      const ProfileResponse(id: 'fallback', email: 'fallback@example.com', firstName: 'fallback', lastName: 'fallback'),
    );
    ProfileResponse mutateFallback(ProfileResponse? current) => cachedProfile;
    Object? toJsonFallback(ProfileResponse value) => null;
    ProfileResponse fromJsonFallback(Object? json) => cachedProfile;
    registerFallbackValue(mutateFallback);
    registerFallbackValue(toJsonFallback);
    registerFallbackValue(fromJsonFallback);
    OfflineOperation operationFallback() => OfflineOperation(
      id: 'fallback-op',
      entityType: 'profile',
      operationType: OperationType.update,
      payload: const {},
      status: OperationStatus.pending,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    OfflineOperation mergeIntoFallback(OfflineOperation existing) => existing;
    registerFallbackValue(operationFallback);
    registerFallbackValue(mergeIntoFallback);
  });

  setUp(() {
    dataSource = MockProfileDataSource();
    mediaDataSource = MockMediaDataSource();
    userLocalDataSource = MockUserLocalDataSource();
    profileLocalDataSource = MockProfileLocalDataSource();
    connectivity = MockConnectivityService();
    operationQueue = MockOperationQueue();
    offlineMutationStore = MockOfflineMutationStore();
    repository = ProfileRepositoryImpl(
      dataSource: dataSource,
      mediaDataSource: mediaDataSource,
      userLocalDataSource: userLocalDataSource,
      profileLocalDataSource: profileLocalDataSource,
      connectivity: connectivity,
      operationQueue: operationQueue,
      offlineMutationStore: offlineMutationStore,
    );
    when(() => connectivity.isOnline).thenAnswer((_) async => true);
    when(() => profileLocalDataSource.read()).thenAnswer((_) async => cachedProfile);
    when(() => profileLocalDataSource.write(any())).thenAnswer((_) async {});
    when(() => userLocalDataSource.read()).thenAnswer(
      (_) async => UserResponse(id: cachedProfile.id, email: cachedProfile.email, createdAt: DateTime(2026)),
    );
    when(() => operationQueue.all()).thenAnswer((_) async => []);
  });

  group('getProfile', () {
    test('online: fetches from the server and caches the result', () async {
      final response = cachedProfile.copyWith(firstName: 'Jane');
      when(() => dataSource.getProfile()).thenAnswer((_) async => response);

      final result = await repository.getProfile();

      expect(result.isRight, isTrue);
      result.fold((_) => fail('expected Right'), (profile) => expect(profile.firstName, 'Jane'));
      verify(() => profileLocalDataSource.write(any())).called(1);
    });

    test('offline: falls back to the cached profile', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.getProfile();

      result.fold((_) => fail('expected Right'), (profile) => expect(profile.id, cachedProfile.id));
      verifyNever(() => dataSource.getProfile());
    });

    test('offline with nothing cached: fails', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(() => profileLocalDataSource.read()).thenAnswer((_) async => null);

      final result = await repository.getProfile();

      expect(result.isLeft, isTrue);
    });
  });

  group('updateProfile — online', () {
    test('updates first/last name without resending the current avatar id', () async {
      final updated = cachedProfile.copyWith(firstName: 'Jane', lastName: 'Smith');
      when(() => dataSource.updateProfile(any())).thenAnswer((_) async => updated);

      final result = await repository.updateProfile(firstName: 'Jane', lastName: 'Smith');

      result.fold((_) => fail('expected Right'), (profile) {
        expect(profile.firstName, 'Jane');
        expect(profile.avatarId, cachedProfile.avatar);
      });
      verify(
        () => dataSource.updateProfile(
          any(
            that: isA<ProfileUpdateRequest>()
                .having((request) => request.firstName, 'firstName', 'Jane')
                .having((request) => request.lastName, 'lastName', 'Smith')
                .having((request) => request.avatar, 'avatar', isNull),
          ),
        ),
      ).called(1);
    });

    test('uploads a newly picked avatar before saving', () async {
      when(
        () => mediaDataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => 'media-2');
      when(() => dataSource.updateProfile(any())).thenAnswer(
        (invocation) async =>
            cachedProfile.copyWith(avatar: (invocation.positionalArguments.single as ProfileUpdateRequest).avatar),
      );

      final result = await repository.updateProfile(
        firstName: 'John',
        lastName: 'Doe',
        newAvatarLocalFilePath: '/tmp/avatar.jpg',
      );

      result.fold((_) => fail('expected Right'), (profile) => expect(profile.avatarId, 'media-2'));
      verify(
        () => mediaDataSource.uploadMedia(
          filePath: '/tmp/avatar.jpg',
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    });

    test('removeAvatar sends an empty string, per auth-service contract', () async {
      when(() => dataSource.updateProfile(any())).thenAnswer(
        (invocation) async => cachedProfile.copyWith(
          clearAvatar: true,
          avatar: (invocation.positionalArguments.single as ProfileUpdateRequest).avatar,
        ),
      );

      final result = await repository.updateProfile(firstName: 'John', lastName: 'Doe', removeAvatar: true);

      result.fold((_) => fail('expected Right'), (profile) => expect(profile.avatarId, isNull));
      verify(
        () => dataSource.updateProfile(
          any(that: isA<ProfileUpdateRequest>().having((request) => request.avatar, 'avatar', '')),
        ),
      ).called(1);
    });

    test('server failure surfaces directly, without falling back to an offline queue', () async {
      when(() => dataSource.updateProfile(any())).thenThrow(
        const ServerException(statusCode: 422, code: 'first_name_required', message: 'First name is required'),
      );

      final result = await repository.updateProfile(firstName: '', lastName: 'Doe');

      expect(result.isLeft, isTrue);
      verifyNever(
        () => offlineMutationStore.saveWithConsolidatedOperation<ProfileResponse>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          matchingOperationTypes: any(named: 'matchingOperationTypes'),
          operation: any(named: 'operation'),
          mergeInto: any(named: 'mergeInto'),
        ),
      );
    });
  });

  group('updateProfile — offline', () {
    setUp(() {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(
        () => offlineMutationStore.saveWithConsolidatedOperation<ProfileResponse>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          matchingOperationTypes: any(named: 'matchingOperationTypes'),
          operation: any(named: 'operation'),
          mergeInto: any(named: 'mergeInto'),
        ),
      ).thenAnswer((invocation) async {
        final mutate = invocation.namedArguments[#mutate] as ProfileResponse Function(ProfileResponse?);
        mutate(cachedProfile);
      });
    });

    test('queues a consolidated update with no avatar key when the avatar is untouched', () async {
      final result = await repository.updateProfile(firstName: 'Jane', lastName: 'Doe');

      result.fold((_) => fail('expected Right'), (profile) => expect(profile.firstName, 'Jane'));
      final captured = verify(
        () => offlineMutationStore.saveWithConsolidatedOperation<ProfileResponse>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          entityType: 'profile',
          entityId: cachedProfile.id,
          matchingOperationTypes: {OperationType.update},
          operation: captureAny(named: 'operation'),
          mergeInto: any(named: 'mergeInto'),
        ),
      ).captured;
      final builtOperation = (captured.single as OfflineOperation Function())();
      expect(builtOperation.payload, {'firstName': 'Jane', 'lastName': 'Doe'});
      verifyNever(() => dataSource.updateProfile(any()));
    });

    test('a picked avatar stays local-only until it syncs', () async {
      final result = await repository.updateProfile(
        firstName: 'John',
        lastName: 'Doe',
        newAvatarLocalFilePath: '/tmp/avatar.jpg',
      );

      result.fold((_) => fail('expected Right'), (profile) {
        expect(profile.avatarLocalFilePath, '/tmp/avatar.jpg');
        expect(profile.avatarId, cachedProfile.avatar);
      });
      verifyNever(
        () => mediaDataSource.uploadMedia(
          filePath: any(named: 'filePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
        ),
      );
    });

    test('resolves the user id from the auth cache when no profile has ever been fetched', () async {
      when(() => profileLocalDataSource.read()).thenAnswer((_) async => null);
      when(
        () => offlineMutationStore.saveWithConsolidatedOperation<ProfileResponse>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          entityType: any(named: 'entityType'),
          entityId: any(named: 'entityId'),
          matchingOperationTypes: any(named: 'matchingOperationTypes'),
          operation: any(named: 'operation'),
          mergeInto: any(named: 'mergeInto'),
        ),
      ).thenAnswer((invocation) async {
        final mutate = invocation.namedArguments[#mutate] as ProfileResponse Function(ProfileResponse?);
        mutate(null);
      });

      final result = await repository.updateProfile(firstName: 'Jane', lastName: 'Doe');

      expect(result.isRight, isTrue);
      verify(
        () => offlineMutationStore.saveWithConsolidatedOperation<ProfileResponse>(
          cacheKey: any(named: 'cacheKey'),
          mutate: any(named: 'mutate'),
          toJson: any(named: 'toJson'),
          fromJson: any(named: 'fromJson'),
          entityType: 'profile',
          entityId: cachedProfile.id,
          matchingOperationTypes: any(named: 'matchingOperationTypes'),
          operation: any(named: 'operation'),
          mergeInto: any(named: 'mergeInto'),
        ),
      ).called(1);
    });
  });

  test('updateProfile fails fast when there is no cached user at all', () async {
    when(() => profileLocalDataSource.read()).thenAnswer((_) async => null);
    when(() => userLocalDataSource.read()).thenAnswer((_) async => null);

    final result = await repository.updateProfile(firstName: 'Jane', lastName: 'Doe');

    expect(result.isLeft, isTrue);
  });
}
