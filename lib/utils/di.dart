import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/http/token_refresher.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/core/storage/secure_storage.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:beebase/data/data_source/authentication_data_source.dart';
import 'package:beebase/data/data_source/interface/authentication_data_source.dart';
import 'package:beebase/data/repositories/authentication_repository_impl.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/login_cubit/login_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/register_cubit/register_cubit.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/router/guardes/authentication_guard.dart';
import 'package:beebase/utils/app_config.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

final di = GetIt.instance;

Future<void> initDi() async {
  // #region Core
  di.registerLazySingleton<SecureStorage>(() => const SecureStorage());
  di.registerLazySingleton<TokenStorage>(
    () => TokenStorage(secureStorage: di()),
  );
  di.registerLazySingleton<SessionService>(() => SessionService());
  // #endregion

  // #region External
  di.registerFactory<DioClient>(
    () => DioClient(baseUrl: AppConfig.apiEndPoint),
  );

  final cookieDirectory = await getApplicationSupportDirectory();
  final cookieJar = PersistCookieJar(
    storage: FileStorage('${cookieDirectory.path}/.cookies'),
  );
  di.registerLazySingleton<CookieJar>(() => cookieJar);
  di.registerLazySingleton<CookieManager>(() => CookieManager(di()));
  // #endregion

  // #region Interceptors
  di.registerLazySingleton<TokenRefresher>(
    () => TokenRefresher(
      dioClient: di<DioClient>().copyWith(interceptors: [di<CookieManager>()]),
      tokenStorage: di(),
      sessionService: di(),
    ),
  );
  di.registerLazySingleton<AuthenticationInterceptor>(
    () => AuthenticationInterceptor(
      tokenStorage: di(),
      tokenRefresher: di(),
      sessionService: di(),
    ),
  );
  di.registerLazySingleton<InterceptorResolver>(
    () => InterceptorResolver({
      CookieManager: di<CookieManager>(),
      AuthenticationInterceptor: di<AuthenticationInterceptor>(),
    }),
  );
  // #endregion

  // #region Data Source
  di.registerLazySingleton<AuthenticationDataSource>(
    () => AuthenticationDataSource(dioClient: di(), resolver: di()),
  );
  di.registerLazySingleton<IAuthenticationDataSource>(
    () => di<AuthenticationDataSource>(),
  );
  // #endregion

  // #region Repositories
  di.registerLazySingleton<AuthenticationRepository>(
    () => AuthenticationRepositoryImpl(dataSource: di(), tokenStorage: di()),
  );
  // #endregion

  // #region Router
  di.registerLazySingleton<AuthenticationGuard>(
    () => AuthenticationGuard(tokenStorage: di()),
  );
  di.registerLazySingleton<AppRouter>(
    () => AppRouter(authenticationGuard: di()),
  );
  // #endregion

  // #region Blocs
  di.registerLazySingleton<AuthenticationCubit>(
    () => AuthenticationCubit(repository: di(), sessionService: di()),
  );
  di.registerFactory<LoginCubit>(
    () => LoginCubit(repository: di(), authenticationCubit: di()),
  );
  di.registerFactory<RegisterCubit>(
    () => RegisterCubit(repository: di(), authenticationCubit: di()),
  );
  // #endregion
}
