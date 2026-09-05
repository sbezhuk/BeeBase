import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/http/token_refresher.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/location/location_service.dart';
import 'package:beebase/core/media/media_image_cache.dart';
import 'package:beebase/core/media/media_image_cache_manager.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/core/storage/database/apiary_database.dart';
import 'package:beebase/core/storage/secure_storage.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:beebase/data/data_source/apiary_data_source.dart';
import 'package:beebase/data/data_source/apiary_local_data_source_impl.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/authentication_data_source.dart';
import 'package:beebase/data/data_source/hive_data_source.dart';
import 'package:beebase/data/data_source/hive_local_data_source_impl.dart';
import 'package:beebase/data/data_source/inspection_data_source.dart';
import 'package:beebase/data/data_source/inspection_local_data_source_impl.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/authentication_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/data_source/interface/password_change_data_source.dart';
import 'package:beebase/data/data_source/interface/password_reset_data_source.dart';
import 'package:beebase/data/data_source/interface/profile_data_source.dart';
import 'package:beebase/data/data_source/interface/statistics_data_source.dart';
import 'package:beebase/data/data_source/media_data_source.dart';
import 'package:beebase/data/data_source/profile_data_source.dart';
import 'package:beebase/data/data_source/statistics_data_source.dart';
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:beebase/data/repositories/authentication_repository_impl.dart';
import 'package:beebase/data/repositories/hive_repository_impl.dart';
import 'package:beebase/data/repositories/inspection_repository_impl.dart';
import 'package:beebase/data/repositories/media_repository_impl.dart';
import 'package:beebase/data/repositories/owner_image_writer.dart';
import 'package:beebase/data/repositories/profile_repository_impl.dart';
import 'package:beebase/data/repositories/statistics_repository_impl.dart';
import 'package:beebase/data/sync/apiary_synchronizer.dart';
import 'package:beebase/data/sync/data_synchronizer.dart';
import 'package:beebase/data/sync/hive_synchronizer.dart';
import 'package:beebase/data/sync/inspection_synchronizer.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/domain/repositories/inspection_reader.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/domain/repositories/owner_image_writer.dart';
import 'package:beebase/domain/repositories/password_changer.dart';
import 'package:beebase/domain/repositories/password_reset_repository.dart';
import 'package:beebase/domain/repositories/profile_reader.dart';
import 'package:beebase/domain/repositories/profile_writer.dart';
import 'package:beebase/domain/repositories/statistics_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_delete_cubit/apiary_delete_cubit.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_details_cubit/apiary_details_cubit.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_form_cubit/apiary_form_cubit.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_list_cubit/apiary_list_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/forgot_password_email_cubit/forgot_password_email_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/forgot_password_otp_cubit/forgot_password_otp_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/login_cubit/login_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/login_otp_cubit/login_otp_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/register_cubit/register_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/reset_password_cubit/reset_password_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/totp_setup_cubit/totp_setup_cubit.dart';
import 'package:beebase/presentation/home/cubit/dashboard_cubit/dashboard_cubit.dart';
import 'package:beebase/presentation/hive/cubit/hive_delete_cubit/hive_delete_cubit.dart';
import 'package:beebase/presentation/hive/cubit/hive_form_cubit/hive_form_cubit.dart';
import 'package:beebase/presentation/hive/cubit/hive_list_cubit/hive_list_cubit.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_delete_cubit/inspection_delete_cubit.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_form_cubit/inspection_form_cubit.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_list_cubit/inspection_list_cubit.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/profile/avatar_image_resolver.dart';
import 'package:beebase/presentation/profile/cubit/change_password_cubit/change_password_cubit.dart';
import 'package:beebase/presentation/profile/cubit/profile_cubit/profile_cubit.dart';
import 'package:beebase/presentation/profile/cubit/profile_edit_cubit/profile_edit_cubit.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/router/guardes/authentication_guard.dart';
import 'package:beebase/utils/app_config.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

final di = GetIt.instance;

Future<void> initDi() async {
  // #region Core
  di.registerLazySingleton<SecureStorage>(() => const SecureStorage());
  di.registerLazySingleton<TokenStorage>(
    () => TokenStorage(secureStorage: di()),
  );
  di.registerLazySingleton<ApiaryDatabase>(() => ApiaryDatabase());
  di.registerLazySingleton<NetworkInfo>(() => NetworkInfo()..startMonitoring());
  di.registerLazySingleton<INetworkInfo>(() => di<NetworkInfo>());
  di.registerLazySingleton<SessionService>(() => SessionService());
  di.registerLazySingleton<LocationService>(LocationService.new);
  di.registerLazySingleton<ApiaryListRefreshNotifier>(
    ApiaryListRefreshNotifier.new,
  );
  di.registerLazySingleton<HiveListRefreshNotifier>(
    HiveListRefreshNotifier.new,
  );
  di.registerLazySingleton<InspectionListRefreshNotifier>(
    InspectionListRefreshNotifier.new,
  );
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

  // The one image cache every `CachedMediaImage` renders through. Reads the
  // access token per request (media URLs are authenticated) rather than
  // capturing one, so an image loaded after a token refresh still succeeds.
  di
    ..registerLazySingleton<MediaImageCacheManager>(
      () => MediaImageCacheManager(accessToken: di<TokenStorage>().accessToken),
    )
    ..registerLazySingleton<IMediaImageCache>(
      () => di<MediaImageCacheManager>(),
    )
    // `CachedMediaImage` resolves the manager by its `flutter_cache_manager`
    // supertype rather than the concrete class, so a widget test can stand
    // in its own without touching the filesystem.
    ..registerLazySingleton<BaseCacheManager>(
      () => di<MediaImageCacheManager>(),
    );
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
  di.registerLazySingleton<IPasswordChangeDataSource>(
    () => di<AuthenticationDataSource>(),
  );
  di.registerLazySingleton<IPasswordResetDataSource>(
    () => di<AuthenticationDataSource>(),
  );
  di.registerLazySingleton<ApiaryDataSource>(
    () => ApiaryDataSource(dioClient: di(), resolver: di()),
  );
  di.registerLazySingleton<IApiaryDataSource>(() => di<ApiaryDataSource>());
  di.registerLazySingleton<ApiaryLocalDataSourceImpl>(
    () => ApiaryLocalDataSourceImpl(database: di()),
  );
  di.registerLazySingleton<IApiaryLocalDataSource>(
    () => di<ApiaryLocalDataSourceImpl>(),
  );
  di.registerLazySingleton<HiveDataSource>(
    () => HiveDataSource(dioClient: di(), resolver: di()),
  );
  di.registerLazySingleton<IHiveDataSource>(() => di<HiveDataSource>());
  di.registerLazySingleton<HiveLocalDataSourceImpl>(
    () => HiveLocalDataSourceImpl(database: di()),
  );
  di.registerLazySingleton<IHiveLocalDataSource>(
    () => di<HiveLocalDataSourceImpl>(),
  );
  di.registerLazySingleton<InspectionDataSource>(
    () => InspectionDataSource(dioClient: di(), resolver: di()),
  );
  di.registerLazySingleton<IInspectionDataSource>(
    () => di<InspectionDataSource>(),
  );
  di.registerLazySingleton<InspectionLocalDataSourceImpl>(
    () => InspectionLocalDataSourceImpl(database: di()),
  );
  di.registerLazySingleton<IInspectionLocalDataSource>(
    () => di<InspectionLocalDataSourceImpl>(),
  );
  di.registerLazySingleton<MediaDataSource>(
    () => MediaDataSource(dioClient: di(), resolver: di()),
  );
  di.registerLazySingleton<IMediaDataSource>(() => di<MediaDataSource>());
  di.registerLazySingleton<ProfileDataSource>(
    () => ProfileDataSource(dioClient: di(), resolver: di()),
  );
  di.registerLazySingleton<IProfileDataSource>(() => di<ProfileDataSource>());
  di.registerLazySingleton<StatisticsDataSource>(
    () => StatisticsDataSource(dioClient: di(), resolver: di()),
  );
  di.registerLazySingleton<IStatisticsDataSource>(
    () => di<StatisticsDataSource>(),
  );
  // #endregion

  // #region Repositories
  di.registerLazySingleton<AuthenticationRepositoryImpl>(
    () => AuthenticationRepositoryImpl(
      dataSource: di(),
      passwordChangeDataSource: di(),
      passwordResetDataSource: di(),
      tokenStorage: di(),
    ),
  );
  di.registerLazySingleton<AuthenticationRepository>(
    () => di<AuthenticationRepositoryImpl>(),
  );
  di.registerLazySingleton<IPasswordChanger>(
    () => di<AuthenticationRepositoryImpl>(),
  );
  di.registerLazySingleton<IPasswordResetFlow>(
    () => di<AuthenticationRepositoryImpl>(),
  );
  di.registerLazySingleton<ApiaryRepositoryImpl>(
    () => ApiaryRepositoryImpl(
      dataSource: di(),
      localDataSource: di(),
      hiveLocalDataSource: di(),
      inspectionLocalDataSource: di(),
      networkInfo: di(),
    ),
  );
  di.registerLazySingleton<IApiaryReader>(() => di<ApiaryRepositoryImpl>());
  di.registerLazySingleton<IApiaryWriter>(() => di<ApiaryRepositoryImpl>());
  di.registerLazySingleton<ApiarySynchronizer>(
    () => ApiarySynchronizer(
      localDataSource: di(),
      apiaryRemoteDataSource: di(),
      mediaRemoteDataSource: di(),
      networkInfo: di(),
      refreshNotifier: di(),
    ),
  );
  di.registerLazySingleton<IApiarySynchronizer>(() => di<ApiarySynchronizer>());
  di.registerLazySingleton<HiveRepositoryImpl>(
    () => HiveRepositoryImpl(
      dataSource: di(),
      localDataSource: di(),
      inspectionLocalDataSource: di(),
      networkInfo: di(),
    ),
  );
  di.registerLazySingleton<IHiveReader>(() => di<HiveRepositoryImpl>());
  di.registerLazySingleton<IHiveWriter>(() => di<HiveRepositoryImpl>());
  di.registerLazySingleton<HiveSynchronizer>(
    () => HiveSynchronizer(
      localDataSource: di(),
      apiaryLocalDataSource: di(),
      hiveRemoteDataSource: di(),
      mediaRemoteDataSource: di(),
      networkInfo: di(),
      refreshNotifier: di(),
    ),
  );
  di.registerLazySingleton<IHiveSynchronizer>(() => di<HiveSynchronizer>());
  di.registerLazySingleton<IOwnerImageWriter>(
    () => OwnerImageWriter(apiaryWriter: di(), hiveWriter: di()),
  );
  di.registerLazySingleton<InspectionRepositoryImpl>(
    () => InspectionRepositoryImpl(
      dataSource: di(),
      localDataSource: di(),
      networkInfo: di(),
    ),
  );
  di.registerLazySingleton<IInspectionReader>(
    () => di<InspectionRepositoryImpl>(),
  );
  di.registerLazySingleton<IInspectionWriter>(
    () => di<InspectionRepositoryImpl>(),
  );
  di.registerLazySingleton<InspectionSynchronizer>(
    () => InspectionSynchronizer(
      localDataSource: di(),
      hiveLocalDataSource: di(),
      inspectionRemoteDataSource: di(),
      networkInfo: di(),
      refreshNotifier: di(),
    ),
  );
  di.registerLazySingleton<IInspectionSynchronizer>(
    () => di<InspectionSynchronizer>(),
  );
  di.registerLazySingleton<DataSynchronizer>(
    () => DataSynchronizer(
      apiarySynchronizer: di<IApiarySynchronizer>(),
      hiveSynchronizer: di<IHiveSynchronizer>(),
      inspectionSynchronizer: di<IInspectionSynchronizer>(),
    ),
  );
  di.registerLazySingleton<IDataSynchronizer>(() => di<DataSynchronizer>());
  di.registerLazySingleton<MediaRepositoryImpl>(
    () => MediaRepositoryImpl(
      dataSource: di(),
      imageCache: di(),
      ownerImageWriter: di(),
      localDataSource: di(),
      networkInfo: di(),
    ),
  );
  di.registerLazySingleton<IMediaReader>(() => di<MediaRepositoryImpl>());
  di.registerLazySingleton<IMediaWriter>(() => di<MediaRepositoryImpl>());
  di.registerLazySingleton<ProfileRepositoryImpl>(
    () => ProfileRepositoryImpl(
      dataSource: di(),
      mediaDataSource: di(),
      imageCache: di(),
    ),
  );
  di.registerLazySingleton<IProfileReader>(() => di<ProfileRepositoryImpl>());
  di.registerLazySingleton<IProfileWriter>(() => di<ProfileRepositoryImpl>());
  di.registerLazySingleton<StatisticsRepositoryImpl>(
    () => StatisticsRepositoryImpl(dataSource: di()),
  );
  di.registerLazySingleton<IStatisticsReader>(
    () => di<StatisticsRepositoryImpl>(),
  );
  di.registerLazySingleton<AvatarImageResolver>(
    () => AvatarImageResolver(mediaReader: di()),
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
  di.registerFactory<LoginCubit>(() => LoginCubit(repository: di()));
  di.registerFactory<RegisterCubit>(() => RegisterCubit(repository: di()));
  di.registerFactory<TotpSetupCubit>(
    () => TotpSetupCubit(repository: di(), authenticationCubit: di()),
  );
  di.registerFactory<LoginOtpCubit>(
    () => LoginOtpCubit(repository: di(), authenticationCubit: di()),
  );
  di.registerFactory<ChangePasswordCubit>(
    () => ChangePasswordCubit(repository: di(), authenticationCubit: di()),
  );
  di.registerFactory<ForgotPasswordEmailCubit>(
    () => ForgotPasswordEmailCubit(repository: di()),
  );
  di.registerFactory<ForgotPasswordOtpCubit>(
    () => ForgotPasswordOtpCubit(repository: di()),
  );
  di.registerFactory<ResetPasswordCubit>(
    () => ResetPasswordCubit(repository: di()),
  );
  di.registerFactory<DashboardCubit>(
    () => DashboardCubit(
      statisticsReader: di(),
      apiaryReader: di(),
      hiveReader: di(),
      inspectionReader: di(),
      apiaryRefreshNotifier: di(),
      hiveRefreshNotifier: di(),
      inspectionRefreshNotifier: di(),
    ),
  );
  di.registerFactory<ApiaryListCubit>(
    () => ApiaryListCubit(
      reader: di(),
      hiveReader: di(),
      refreshNotifier: di(),
      hiveRefreshNotifier: di(),
    ),
  );
  di.registerFactoryParam<ApiaryFormCubit, Apiary?, void>(
    (initial, _) => ApiaryFormCubit(
      writer: di(),
      refreshNotifier: di(),
      locationService: di(),
      initial: initial,
    ),
  );
  di.registerFactoryParam<ApiaryDeleteCubit, Apiary, void>(
    (apiary, _) =>
        ApiaryDeleteCubit(writer: di(), apiary: apiary, refreshNotifier: di()),
  );
  di.registerFactoryParam<ApiaryDetailsCubit, Apiary, void>(
    (apiary, _) => ApiaryDetailsCubit(
      apiary: apiary,
      reader: di(),
      hiveReader: di(),
      refreshNotifier: di(),
      hiveRefreshNotifier: di(),
    ),
  );
  di.registerFactoryParam<HiveListCubit, String, void>(
    (apiaryId, _) =>
        HiveListCubit(reader: di(), apiaryId: apiaryId, refreshNotifier: di()),
  );
  di.registerFactoryParam<HiveFormCubit, String, Hive?>(
    (apiaryId, initial) => HiveFormCubit(
      writer: di(),
      apiaryId: apiaryId,
      refreshNotifier: di(),
      initial: initial,
    ),
  );
  di.registerFactoryParam<HiveDeleteCubit, Hive, void>(
    (hive, _) =>
        HiveDeleteCubit(writer: di(), hive: hive, refreshNotifier: di()),
  );
  di.registerFactoryParam<InspectionListCubit, String, void>(
    (hiveId, _) => InspectionListCubit(
      reader: di(),
      hiveId: hiveId,
      refreshNotifier: di(),
    ),
  );
  di.registerFactoryParam<InspectionFormCubit, String, Inspection?>(
    (hiveId, initial) => InspectionFormCubit(
      writer: di(),
      hiveId: hiveId,
      refreshNotifier: di(),
      initial: initial,
    ),
  );
  di.registerFactoryParam<InspectionDeleteCubit, Inspection, void>(
    (inspection, _) => InspectionDeleteCubit(
      writer: di(),
      inspection: inspection,
      refreshNotifier: di(),
    ),
  );
  di.registerFactoryParam<MediaGalleryCubit, MediaOwnerType, String?>(
    (ownerType, ownerId) => MediaGalleryCubit(
      reader: di(),
      writer: di(),
      ownerType: ownerType,
      ownerId: ownerId,
      notifyOwnerListChanged: switch (ownerType) {
        MediaOwnerType.apiary => di<ApiaryListRefreshNotifier>().notify,
        MediaOwnerType.hive => di<HiveListRefreshNotifier>().notify,
      },
      ownerListChanges: switch (ownerType) {
        MediaOwnerType.apiary => di<ApiaryListRefreshNotifier>().onChanged,
        MediaOwnerType.hive => di<HiveListRefreshNotifier>().onChanged,
      },
      // Apiary/hive-service is the source of truth for "which media ids
      // belong to me" (see `ApiaryResponse.images`/`HiveResponse.images`) —
      // a gallery reload sources its `ids` from here instead of asking
      // media-service "what's attached to owner X" the old owner-scoped way.
      resolveImages: switch (ownerType) {
        MediaOwnerType.apiary =>
          (id) async => (await di<IApiaryReader>().getApiary(
            id,
          )).fold((_) => const <String>[], (apiary) => apiary.images),
        MediaOwnerType.hive => (id) async => (await di<IHiveReader>().getHive(
          id,
        )).fold((_) => const <String>[], (hive) => hive.images),
      },
    ),
  );
  di.registerFactory<ProfileCubit>(
    () => ProfileCubit(reader: di(), authenticationCubit: di()),
  );
  di.registerFactory<ProfileEditCubit>(
    () => ProfileEditCubit(writer: di(), authenticationCubit: di()),
  );
  // #endregion
}
