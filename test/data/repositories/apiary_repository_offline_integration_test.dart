import 'package:beebase/core/offline/offline_mutation_store.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/sqlite_local_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/storage/sqlite_test_helper.dart';

class MockApiaryDataSource extends Mock implements IApiaryDataSource {}

class MockConnectivityService extends Mock implements IConnectivityService {}

class MockOperationQueue extends Mock implements OperationQueue {}

class MockOfflineMutationStore extends Mock implements OfflineMutationStore {}

/// Exercises [ApiaryRepositoryImpl] against a real (ffi-backed) SQLite
/// database rather than a mocked [LocalDataSource] — the unit tests in
/// `apiary_repository_impl_test.dart` mock the cache entirely, so they can't
/// catch a bug in the actual JSON round trip through `key_value_cache` (see
/// `SqliteLocalDataSource`). Only the data source and connectivity check are
/// mocked; everything downstream of that is the real offline stack.
void main() {
  setUpAll(() {
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
    registerFallbackValue(const ApiaryRequest(name: 'fallback'));
  });

  late MockApiaryDataSource dataSource;
  late MockConnectivityService connectivity;
  late MockOperationQueue operationQueue;
  late SqliteLocalDataSource<List<ApiaryResponse>> localDataSource;
  late ApiaryRepositoryImpl repository;

  setUp(() async {
    final database = await openTestDatabase();
    localDataSource = SqliteLocalDataSource<List<ApiaryResponse>>(
      database: database,
      key: apiaryCacheKey,
      toJson: (apiaries) => apiaries.map((apiary) => apiary.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>)
          .map((item) => ApiaryResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    dataSource = MockApiaryDataSource();
    connectivity = MockConnectivityService();
    operationQueue = MockOperationQueue();
    when(
      () => operationQueue.all(),
    ).thenAnswer((_) async => <OfflineOperation>[]);
    repository = ApiaryRepositoryImpl(
      dataSource: dataSource,
      localDataSource: localDataSource,
      connectivity: connectivity,
      operationQueue: operationQueue,
      offlineMutationStore: MockOfflineMutationStore(),
    );
  });

  test(
    'an apiary fetched while online is still visible from the real cache once offline',
    () async {
      final response = ApiaryResponse(
        id: 'apiary-1',
        name: 'Back Garden',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => dataSource.getApiaries(any(that: isA<PageRequest>())),
      ).thenAnswer(
        (_) async => PaginatedResponse(
          items: [response],
          pagination: const PaginationMeta(
            page: 1,
            limit: 20,
            total: 1,
            totalPages: 1,
            hasNext: false,
            hasPrevious: false,
          ),
        ),
      );
      when(() => connectivity.isOnline).thenAnswer((_) async => true);
      final onlineResult = await repository.getApiaries(page: 1, limit: 20);
      onlineResult.fold(
        (failure) => fail('expected Right, got $failure'),
        (page) => expect(page.items.single.id, 'apiary-1'),
      );

      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      final offlineResult = await repository.getApiaries(page: 1, limit: 20);

      offlineResult.fold(
        (failure) => fail(
          'expected cached data offline but got a failure: ${failure.message}',
        ),
        (page) => expect(page.items.map((apiary) => apiary.id), ['apiary-1']),
      );
    },
  );

  test(
    'a device offline with nothing ever cached gets an empty page, not an error',
    () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      final result = await repository.getApiaries(page: 1, limit: 20);

      result.fold(
        (failure) => fail(
          'offline with an empty cache must not surface as a Failure, got: ${failure.message}',
        ),
        (page) {
          expect(page.items, isEmpty);
          expect(page.hasNext, isFalse);
        },
      );
      verifyNever(() => dataSource.getApiaries(any()));
    },
  );
}
