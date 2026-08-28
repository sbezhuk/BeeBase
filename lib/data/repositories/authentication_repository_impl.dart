import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:beebase/data/data_source/interface/authentication_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/extensions/user_extension.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';

final class AuthenticationRepositoryImpl extends Repository implements AuthenticationRepository {
  AuthenticationRepositoryImpl({required this.dataSource, required this.tokenStorage, required this.userLocalDataSource});

  final IAuthenticationDataSource dataSource;
  final TokenStorage tokenStorage;
  final LocalDataSource<UserResponse> userLocalDataSource;

  @override
  Future<Either<Failure, User>> register({required String email, required String password}) {
    return on(() async {
      final session = await dataSource.register(email: email, password: password);
      await tokenStorage.saveAccessToken(session.accessToken);
      await userLocalDataSource.write(session.user);
      return session.user.toEntity();
    });
  }

  @override
  Future<Either<Failure, User>> login({required String email, required String password}) {
    return on(() async {
      final session = await dataSource.login(email: email, password: password);
      await tokenStorage.saveAccessToken(session.accessToken);
      await userLocalDataSource.write(session.user);
      return session.user.toEntity();
    });
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() {
    return on(() async {
      final user = await dataSource.getCurrentUser();
      await userLocalDataSource.write(user);
      return user.toEntity();
    });
  }

  /// Restores a previously established session. A network failure here
  /// (no connectivity, timeout) does not mean the session is invalid — it
  /// falls back to the last known user so the app stays usable offline.
  /// Only a failure from the server itself (it explicitly rejected the
  /// token) is treated as a real logout.
  @override
  Future<Either<Failure, User>> restoreSession() async {
    final hasSession = await tokenStorage.hasAccessToken();
    if (!hasSession) {
      return const Left(InternalFailure(ErrorTextKey('core.errors.noActiveSession')));
    }

    final result = await getCurrentUser();
    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      final cachedUser = await userLocalDataSource.read();
      return cachedUser == null ? Left(failure) : Right(cachedUser.toEntity());
    }, (user) => Future.value(Right(user)));
  }

  @override
  Future<void> logout() async {
    try {
      await dataSource.logout();
    } catch (_) {
      // Best-effort: the local session is cleared below regardless of
      // whether the server could be reached to revoke the refresh token.
    }
    await tokenStorage.clear();
    await userLocalDataSource.clear();
  }
}
