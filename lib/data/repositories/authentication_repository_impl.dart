import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:beebase/data/data_source/interface/authentication_data_source.dart';
import 'package:beebase/data/models/extensions/user_extension.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';

final class AuthenticationRepositoryImpl extends Repository
    implements AuthenticationRepository {
  AuthenticationRepositoryImpl({
    required this.dataSource,
    required this.tokenStorage,
  });

  final IAuthenticationDataSource dataSource;
  final TokenStorage tokenStorage;

  @override
  Future<Either<Failure, User>> register({
    required String email,
    required String password,
  }) {
    return on(() async {
      final session = await dataSource.register(
        email: email,
        password: password,
      );
      await tokenStorage.saveAccessToken(session.accessToken);
      return session.user.toEntity();
    });
  }

  @override
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  }) {
    return on(() async {
      final session = await dataSource.login(email: email, password: password);
      await tokenStorage.saveAccessToken(session.accessToken);
      return session.user.toEntity();
    });
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() {
    return on(() async => (await dataSource.getCurrentUser()).toEntity());
  }

  @override
  Future<Either<Failure, User>> restoreSession() async {
    final hasSession = await tokenStorage.hasAccessToken();
    if (!hasSession) {
      return const Left(
        InternalFailure(ErrorTextKey('core.errors.noActiveSession')),
      );
    }
    return getCurrentUser();
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
  }
}
