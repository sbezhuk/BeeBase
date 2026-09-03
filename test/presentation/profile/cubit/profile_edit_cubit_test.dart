import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/domain/entity/profile.dart';
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

  final baseUser = User(id: 'user-1', email: 'john@example.com', createdAt: DateTime(2026));
  final profile = Profile(id: 'user-1', email: 'john@example.com', firstName: 'Jane', lastName: 'Doe');
  final mergedUser = profile.mergeOnto(baseUser);

  setUp(() {
    writer = MockProfileWriter();
    authenticationCubit = AuthenticationCubit(repository: MockAuthenticationRepository(), sessionService: SessionService())
      ..setAuthenticated(baseUser);
  });

  tearDown(() {
    authenticationCubit.close();
  });

  blocTest<ProfileEditCubit, ProfileEditState>(
    'emits Loading then Success and merges the profile onto AuthenticationCubit',
    build: () {
      when(
        () => writer.updateProfile(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          newAvatarLocalFilePath: any(named: 'newAvatarLocalFilePath'),
          removeAvatar: any(named: 'removeAvatar'),
        ),
      ).thenAnswer((_) async => Right(profile));
      return ProfileEditCubit(writer: writer, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.submit(firstName: 'Jane', lastName: 'Doe'),
    expect: () => [const ProfileEditLoading(), ProfileEditSuccess(mergedUser)],
    verify: (_) {
      expect(authenticationCubit.state, AuthenticationAuthenticated(mergedUser));
      verify(
        () => writer.updateProfile(firstName: 'Jane', lastName: 'Doe', newAvatarLocalFilePath: null, removeAvatar: false),
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
      ).thenAnswer((_) async => Left(ServerFailure(code: 'first_name_required', message: 'First name required')));
      return ProfileEditCubit(writer: writer, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.submit(firstName: '', lastName: 'Doe'),
    expect: () => [
      const ProfileEditLoading(),
      ProfileEditError(ServerFailure(code: 'first_name_required', message: 'First name required')),
    ],
    verify: (_) => expect(authenticationCubit.state, AuthenticationAuthenticated(baseUser)),
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
      ).thenAnswer((_) async => Right(profile));
      return ProfileEditCubit(writer: writer, authenticationCubit: authenticationCubit);
    },
    act: (cubit) => cubit.submit(firstName: 'Jane', lastName: 'Doe', newAvatarLocalFilePath: '/tmp/avatar.jpg'),
    expect: () => [const ProfileEditLoading(), ProfileEditSuccess(mergedUser)],
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
