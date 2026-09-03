import 'package:beebase/core/networking/http/dio_client.dart';
import 'package:beebase/core/networking/http/token_refresher.dart';
import 'package:beebase/core/networking/interceptors/authentication_interceptor.dart';
import 'package:beebase/core/location/location_service.dart';
import 'package:beebase/core/networking/interceptors/interceptor_resolver.dart';
import 'package:beebase/core/offline/offline_mutation_store.dart';
import 'package:beebase/core/offline/offline_operations_change_notifier.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_registry.dart';
import 'package:beebase/core/offline/sqlite_offline_mutation_store.dart';
import 'package:beebase/core/offline/sqlite_operation_queue.dart';
import 'package:beebase/core/offline/sync_activity_tracker.dart';
import 'package:beebase/core/offline/sync_engine.dart';
import 'package:beebase/core/offline/sync_engine_impl.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/core/services/connectivity_service_impl.dart';
import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/core/storage/app_database.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/core/storage/secure_storage.dart';
import 'package:beebase/core/storage/token_storage.dart';
import 'package:beebase/data/apiary/apiary_operation_handler.dart';
import 'package:beebase/data/data_source/apiary_data_source.dart';
import 'package:beebase/data/data_source/authentication_data_source.dart';
import 'package:beebase/data/data_source/hive_data_source.dart';
import 'package:beebase/data/data_source/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/authentication_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/data_source/interface/profile_data_source.dart';
import 'package:beebase/data/data_source/interface/statistics_data_source.dart';
import 'package:beebase/data/data_source/media_data_source.dart';
import 'package:beebase/data/data_source/profile_data_source.dart';
import 'package:beebase/data/data_source/sqlite_local_data_source.dart';
import 'package:beebase/data/data_source/statistics_data_source.dart';
import 'package:beebase/data/hive/hive_operation_handler.dart';
import 'package:beebase/data/inspection/inspection_operation_handler.dart';
import 'package:beebase/data/media/media_operation_handler.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/models/profile_response.dart';
import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/data/profile/profile_operation_handler.dart';
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:beebase/data/repositories/authentication_repository_impl.dart';
import 'package:beebase/data/repositories/hive_repository_impl.dart';
import 'package:beebase/data/repositories/inspection_repository_impl.dart';
import 'package:beebase/data/repositories/media_repository_impl.dart';
import 'package:beebase/data/repositories/owner_image_writer.dart';
import 'package:beebase/data/repositories/profile_repository_impl.dart';
import 'package:beebase/data/repositories/statistics_repository_impl.dart';
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
import 'package:beebase/domain/repositories/profile_reader.dart';
import 'package:beebase/domain/repositories/profile_writer.dart';
import 'package:beebase/domain/repositories/statistics_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_delete_cubit/apiary_delete_cubit.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_details_cubit/apiary_details_cubit.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_form_cubit/apiary_form_cubit.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_list_cubit/apiary_list_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/login_cubit/login_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/register_cubit/register_cubit.dart';
import 'package:beebase/presentation/connectivity/cubit/connectivity_cubit/connectivity_cubit.dart';
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
import 'package:beebase/presentation/profile/avatar_path_resolver.dart';
import 'package:beebase/presentation/profile/cubit/profile_cubit/profile_cubit.dart';
import 'package:beebase/presentation/profile/cubit/profile_edit_cubit/profile_edit_cubit.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/router/guardes/authentication_guard.dart';
import 'package:beebase/presentation/sync/cubit/sync_banner_cubit/sync_banner_cubit.dart';
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
  di.registerLazySingleton<LocationService>(
    () => LocationService(connectivity: di()),
  );
  // A leaf with no dependencies of its own (see its doc for why the sync
  // batch's "in progress" flag lives here rather than directly on
  // `SyncEngine`) — must be registered before anything below that depends
  // on it.
  di.registerLazySingleton<SyncActivityTracker>(SyncActivityTracker.new);
  di.registerLazySingleton<ApiaryListRefreshNotifier>(
    () => ApiaryListRefreshNotifier(syncActivity: di<SyncActivityTracker>()),
  );
  di.registerLazySingleton<HiveListRefreshNotifier>(
    () => HiveListRefreshNotifier(syncActivity: di<SyncActivityTracker>()),
  );
  di.registerLazySingleton<InspectionListRefreshNotifier>(
    () =>
        InspectionListRefreshNotifier(syncActivity: di<SyncActivityTracker>()),
  );
  di.registerLazySingleton<ConnectivityService>(ConnectivityService.new);
  di.registerLazySingleton<IConnectivityService>(
    () => di<ConnectivityService>(),
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

  final appDatabase = AppDatabase();
  await appDatabase.open();
  di.registerLazySingleton<AppDatabase>(() => appDatabase);

  di.registerLazySingleton<LocalDataSource<UserResponse>>(
    () => SqliteLocalDataSource<UserResponse>(
      database: di(),
      key: 'cached_user',
      toJson: (user) => user.toJson(),
      fromJson: (json) => UserResponse.fromJson(json as Map<String, dynamic>),
    ),
  );
  di.registerLazySingleton<LocalDataSource<ProfileResponse>>(
    () => SqliteLocalDataSource<ProfileResponse>(
      database: di(),
      key: profileCacheKey,
      toJson: (profile) => profile.toJson(),
      fromJson: (json) =>
          ProfileResponse.fromJson(json as Map<String, dynamic>),
    ),
  );
  di.registerLazySingleton<LocalDataSource<List<ApiaryResponse>>>(
    () => SqliteLocalDataSource<List<ApiaryResponse>>(
      database: di(),
      key: apiaryCacheKey,
      toJson: (apiaries) => apiaries.map((apiary) => apiary.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>)
          .map((item) => ApiaryResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
    ),
  );
  di.registerLazySingleton<LocalDataSource<List<HiveResponse>>>(
    () => SqliteLocalDataSource<List<HiveResponse>>(
      database: di(),
      key: hiveCacheKey,
      toJson: (hives) => hives.map((hive) => hive.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>)
          .map((item) => HiveResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
    ),
  );
  di.registerLazySingleton<LocalDataSource<List<MediaResponse>>>(
    () => SqliteLocalDataSource<List<MediaResponse>>(
      database: di(),
      key: mediaCacheKey,
      toJson: (items) => items.map((response) => response.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>)
          .map((item) => MediaResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
    ),
  );
  di.registerLazySingleton<LocalDataSource<List<InspectionResponse>>>(
    () => SqliteLocalDataSource<List<InspectionResponse>>(
      database: di(),
      key: inspectionCacheKey,
      toJson: (inspections) =>
          inspections.map((inspection) => inspection.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>)
          .map(
            (item) => InspectionResponse.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    ),
  );
  di.registerLazySingleton<LocalMediaStore>(LocalMediaStore.new);
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
  di.registerLazySingleton<ApiaryDataSource>(
    () => ApiaryDataSource(dioClient: di(), resolver: di()),
  );
  di.registerLazySingleton<IApiaryDataSource>(() => di<ApiaryDataSource>());
  di.registerLazySingleton<HiveDataSource>(
    () => HiveDataSource(dioClient: di(), resolver: di()),
  );
  di.registerLazySingleton<IHiveDataSource>(() => di<HiveDataSource>());
  di.registerLazySingleton<InspectionDataSource>(
    () => InspectionDataSource(dioClient: di(), resolver: di()),
  );
  di.registerLazySingleton<IInspectionDataSource>(
    () => di<InspectionDataSource>(),
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

  // #region Offline
  di.registerLazySingleton<OfflineOperationsChangeNotifier>(
    OfflineOperationsChangeNotifier.new,
  );
  di.registerLazySingleton<SqliteOperationQueue>(
    () => SqliteOperationQueue(database: di(), changeNotifier: di()),
  );
  di.registerLazySingleton<OperationQueue>(() => di<SqliteOperationQueue>());
  di.registerLazySingleton<SqliteOfflineMutationStore>(
    () => SqliteOfflineMutationStore(database: di(), changeNotifier: di()),
  );
  di.registerLazySingleton<OfflineMutationStore>(
    () => di<SqliteOfflineMutationStore>(),
  );
  di.registerLazySingleton<ApiaryOperationHandler>(
    () => ApiaryOperationHandler(
      dataSource: di(),
      localDataSource: di(),
      refreshNotifier: di(),
      operationQueue: di(),
      locationService: di(),
    ),
  );
  di.registerLazySingleton<HiveOperationHandler>(
    () => HiveOperationHandler(
      dataSource: di(),
      localDataSource: di(),
      refreshNotifier: di(),
      operationQueue: di(),
    ),
  );
  di.registerLazySingleton<InspectionOperationHandler>(
    () => InspectionOperationHandler(
      dataSource: di(),
      localDataSource: di(),
      refreshNotifier: di(),
      operationQueue: di(),
    ),
  );
  di.registerLazySingleton<MediaOperationHandler>(
    () => MediaOperationHandler(
      dataSource: di(),
      localDataSource: di(),
      localMediaStore: di(),
      operationQueue: di(),
    ),
  );
  di.registerLazySingleton<ProfileOperationHandler>(
    () => ProfileOperationHandler(
      dataSource: di(),
      mediaDataSource: di(),
      localDataSource: di(),
      operationQueue: di(),
    ),
  );
  di.registerLazySingleton<OperationRegistry>(
    () => OperationRegistry({
      'apiary': di<ApiaryOperationHandler>(),
      'hive': di<HiveOperationHandler>(),
      'inspection': di<InspectionOperationHandler>(),
      'media': di<MediaOperationHandler>(),
      'profile': di<ProfileOperationHandler>(),
    }),
  );
  di.registerLazySingleton<SyncEngineImpl>(
    () => SyncEngineImpl(
      queue: di(),
      registry: di(),
      connectivity: di(),
      activity: di(),
    ),
  );
  di.registerLazySingleton<SyncEngine>(() => di<SyncEngineImpl>());
  // #endregion

  // #region Repositories
  di.registerLazySingleton<AuthenticationRepository>(
    () => AuthenticationRepositoryImpl(
      dataSource: di(),
      tokenStorage: di(),
      userLocalDataSource: di(),
    ),
  );
  di.registerLazySingleton<ApiaryRepositoryImpl>(
    () => ApiaryRepositoryImpl(
      dataSource: di(),
      localDataSource: di(),
      connectivity: di(),
      operationQueue: di(),
      offlineMutationStore: di(),
    ),
  );
  di.registerLazySingleton<IApiaryReader>(() => di<ApiaryRepositoryImpl>());
  di.registerLazySingleton<IApiaryWriter>(() => di<ApiaryRepositoryImpl>());
  di.registerLazySingleton<HiveRepositoryImpl>(
    () => HiveRepositoryImpl(
      dataSource: di(),
      localDataSource: di(),
      connectivity: di(),
      operationQueue: di(),
      offlineMutationStore: di(),
    ),
  );
  di.registerLazySingleton<IHiveReader>(() => di<HiveRepositoryImpl>());
  di.registerLazySingleton<IHiveWriter>(() => di<HiveRepositoryImpl>());
  di.registerLazySingleton<IOwnerImageWriter>(
    () => OwnerImageWriter(apiaryWriter: di(), hiveWriter: di()),
  );
  di.registerLazySingleton<InspectionRepositoryImpl>(
    () => InspectionRepositoryImpl(
      dataSource: di(),
      localDataSource: di(),
      connectivity: di(),
      operationQueue: di(),
      offlineMutationStore: di(),
    ),
  );
  di.registerLazySingleton<IInspectionReader>(
    () => di<InspectionRepositoryImpl>(),
  );
  di.registerLazySingleton<IInspectionWriter>(
    () => di<InspectionRepositoryImpl>(),
  );
  di.registerLazySingleton<MediaRepositoryImpl>(
    () => MediaRepositoryImpl(
      dataSource: di(),
      localDataSource: di(),
      localMediaStore: di(),
      connectivity: di(),
      operationQueue: di(),
      offlineMutationStore: di(),
      ownerImageWriter: di(),
    ),
  );
  di.registerLazySingleton<IMediaReader>(() => di<MediaRepositoryImpl>());
  di.registerLazySingleton<IMediaWriter>(() => di<MediaRepositoryImpl>());
  di.registerLazySingleton<ProfileRepositoryImpl>(
    () => ProfileRepositoryImpl(
      dataSource: di(),
      mediaDataSource: di(),
      userLocalDataSource: di(),
      profileLocalDataSource: di(),
      connectivity: di(),
      operationQueue: di(),
      offlineMutationStore: di(),
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
  di.registerLazySingleton<AvatarPathResolver>(
    () => AvatarPathResolver(mediaReader: di(), localMediaStore: di()),
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
  di.registerLazySingleton<SyncBannerCubit>(
    () => SyncBannerCubit(engine: di()),
  );
  di.registerLazySingleton<ConnectivityCubit>(
    () => ConnectivityCubit(connectivity: di()),
  );
  di.registerFactory<LoginCubit>(
    () => LoginCubit(repository: di(), authenticationCubit: di()),
  );
  di.registerFactory<RegisterCubit>(
    () => RegisterCubit(repository: di(), authenticationCubit: di()),
  );
  di.registerFactory<DashboardCubit>(
    () => DashboardCubit(
      statisticsReader: di(),
      apiaryReader: di(),
      hiveReader: di(),
      inspectionReader: di(),
      connectivity: di(),
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
      localMediaStore: di(),
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
      // Apiary/hive-service is now the source of truth for "which media ids
      // belong to me" (see `ApiaryResponse.images`/`HiveResponse.images`) —
      // a gallery reload sources its `ids` from here instead of asking
      // media-service "what's attached to owner X" the old owner-scoped way.
      // A cache read (never `null` on a cache miss — see [Apiary.images]'s
      // default), so this never needs its own network round trip.
      resolveImages: switch (ownerType) {
        MediaOwnerType.apiary =>
          (id) async =>
              (await di<IApiaryReader>().getCachedApiary(id))?.images ??
              const [],
        MediaOwnerType.hive =>
          (id) async =>
              (await di<IHiveReader>().getCachedHive(id))?.images ?? const [],
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
