import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/domain/repositories/profile_writer.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/profile/cubit/profile_edit_cubit/profile_edit_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileWriter extends Mock implements IProfileWriter {}

class MockAuthenticationRepository extends Mock implements AuthenticationRepository {}

void main() {
  late MockProfileWriter writer;
  late AuthenticationCubit authenticationCubit;

  final user = User(id: 'user-1', email: 'john@example.com', createdAt: DateTime(2026), firstName: 'Jane');

  setUp(() {
    writer = MockProfileWriter();
    authenticationCubit = AuthenticationCubit(repository: MockAuthenticationRepository(), sessionService: SessionService());
  });

  tearDown(() {
    authenticationCubit.close();
  });

  blocTest<ProfileEditCubit, ProfileEditState>(
    'emits Loading then Success and updates AuthenticationCubit',
    build: () {
      when(
        () => writer.updateProfile(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          newAvatarLocalFilePath: any(named: 'newAvatarLocalFilePath'),
          removeAvatar: any(named: 'removeAvatar'),
        ),
      ).thenAnswer((_) async => Right(user));
      return ProfileEditCubit(writer: writer, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.submit(firstName: 'Jane', lastName: 'Doe'),
    expect: () => [const ProfileEditLoading(), ProfileEditSuccess(user)],
    verify: (_) {
      expect(authenticationCubit.state, AuthenticationAuthenticated(user));
      verify(
        () => writer.updateProfile(
          firstName: 'Jane',
          lastName: 'Doe',
          newAvatarLocalFilePath: null,
          removeAvatar: false,
        ),
      ).called(1);
    },
  );

  blocTest<ProfileEditCubit, ProfileEditState>(
    'emits Loading then Error on failure, without touching AuthenticationCubit',
    build: () {
      when(
        () => writer.updateProfile(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          newAvatarLocalFilePath: any(named: 'newAvatarLocalFilePath'),
          removeAvatar: any(named: 'removeAvatar'),
        ),
      ).thenAnswer((_) async => Left(ServerFailure(code: 'invalid_name', message: 'Invalid name')));
      return ProfileEditCubit(writer: writer, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.submit(firstName: '', lastName: 'Doe'),
    expect: () => [
      const ProfileEditLoading(),
      ProfileEditError(ServerFailure(code: 'invalid_name', message: 'Invalid name')),
    ],
    verify: (_) => expect(authenticationCubit.state, isNot(isA<AuthenticationAuthenticated>())),
  );

  blocTest<ProfileEditCubit, ProfileEditState>(
    'forwards the picked avatar path and removal flag to the writer',
    build: () {
      when(
        () => writer.updateProfile(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          newAvatarLocalFilePath: any(named: 'newAvatarLocalFilePath'),
          removeAvatar: any(named: 'removeAvatar'),
        ),
      ).thenAnswer((_) async => Right(user));
      return ProfileEditCubit(writer: writer, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.submit(firstName: 'Jane', lastName: 'Doe', newAvatarLocalFilePath: '/tmp/avatar.jpg'),
    expect: () => [const ProfileEditLoading(), ProfileEditSuccess(user)],
    verify: (_) {
      verify(
        () => writer.updateProfile(
          firstName: 'Jane',
          lastName: 'Doe',
          newAvatarLocalFilePath: '/tmp/avatar.jpg',
          removeAvatar: false,
        ),
      ).called(1);
    },
  );
}
