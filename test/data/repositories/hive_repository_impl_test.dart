import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/models/entity_image_response.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/hive_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveDataSource extends Mock implements IHiveDataSource {}

void main() {
  late MockHiveDataSource dataSource;
  late HiveRepositoryImpl repository;

  final hiveResponse1 = HiveResponse(
    id: 'hive-1',
    apiaryId: 'apiary-1',
    name: 'Hive One',
    notes: 'Some notes',
    images: const [
      EntityImageResponse(
        id: 'media-1',
        imageUrl: 'https://api.beebase.test/api/v1/media/media-1/download',
      ),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );

  final hiveResponse2 = HiveResponse(
    id: 'hive-2',
    apiaryId: 'apiary-2',
    name: 'Hive Two',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );

  setUpAll(() {
    registerFallbackValue(const HiveRequest(name: 'fallback'));
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
  });

  setUp(() {
    dataSource = MockHiveDataSource();
    repository = HiveRepositoryImpl(dataSource: dataSource);
  });

  group('getHives', () {
    test('returns mapped Page<Hive> filtered by apiaryId', () async {
      when(() => dataSource.getHives(any())).thenAnswer(
        (_) async => PaginatedResponse(
          items: [hiveResponse1, hiveResponse2],
          pagination: const PaginationMeta(
            page: 1,
            limit: 20,
            total: 2,
            totalPages: 1,
            hasNext: false,
            hasPrevious: false,
          ),
        ),
      );

      final result = await repository.getHives(apiaryId: 'apiary-1', page: 1, limit: 20);

      result.fold(
        (_) => fail('expected Right'),
        (page) {
          expect(page.items.length, 1);
          expect(page.items.first.id, 'hive-1');
          expect(page.items.first.name, 'Hive One');
        },
      );
    });

    test('returns ServerFailure when dataSource throws', () async {
      when(() => dataSource.getHives(any())).thenThrow(
        const ServerException(statusCode: 500, code: 'error', message: 'failed'),
      );

      final result = await repository.getHives(apiaryId: 'apiary-1', page: 1, limit: 20);

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('getHive', () {
    test('returns mapped Hive on success', () async {
      when(() => dataSource.getHive('hive-1')).thenAnswer((_) async => hiveResponse1);

      final result = await repository.getHive('hive-1');

      result.fold(
        (_) => fail('expected Right'),
        (hive) {
          expect(hive.id, 'hive-1');
          expect(hive.name, 'Hive One');
        },
      );
    });
  });

  group('getHiveCounts', () {
    test('counts hives per apiary across pages', () async {
      when(() => dataSource.getHives(any())).thenAnswer(
        (_) async => PaginatedResponse(
          items: [hiveResponse1, hiveResponse2],
          pagination: const PaginationMeta(
            page: 1,
            limit: 50,
            total: 2,
            totalPages: 1,
            hasNext: false,
            hasPrevious: false,
          ),
        ),
      );

      final result = await repository.getHiveCounts();

      result.fold(
        (_) => fail('expected Right'),
        (counts) {
          expect(counts['apiary-1'], 1);
          expect(counts['apiary-2'], 1);
        },
      );
    });
  });

  group('createHive', () {
    test('calls dataSource.createHive and returns mapped Hive', () async {
      when(
        () => dataSource.createHive(any(), apiaryId: 'apiary-1'),
      ).thenAnswer((_) async => hiveResponse1);

      final result = await repository.createHive(
        apiaryId: 'apiary-1',
        name: 'Hive One',
        notes: 'Some notes',
      );

      result.fold(
        (_) => fail('expected Right'),
        (hive) => expect(hive.id, 'hive-1'),
      );
    });
  });

  group('updateHive', () {
    test('calls dataSource.updateHive and returns mapped Hive', () async {
      when(() => dataSource.updateHive('hive-1', any())).thenAnswer((_) async => hiveResponse1);

      final result = await repository.updateHive(
        id: 'hive-1',
        name: 'Hive One',
      );

      result.fold(
        (_) => fail('expected Right'),
        (hive) => expect(hive.id, 'hive-1'),
      );
    });
  });

  group('deleteHive', () {
    test('calls dataSource.deleteHive', () async {
      when(() => dataSource.deleteHive('hive-1')).thenAnswer((_) async {});

      final result = await repository.deleteHive('hive-1');

      expect(result.isRight, isTrue);
      verify(() => dataSource.deleteHive('hive-1')).called(1);
    });

    test('treats 404 as successful delete', () async {
      when(() => dataSource.deleteHive('hive-1')).thenThrow(
        const ServerException(statusCode: 404, code: 'not_found', message: 'Not found'),
      );

      final result = await repository.deleteHive('hive-1');

      expect(result.isRight, isTrue);
    });
  });

  group('addHiveImage', () {
    test('fetches current hive and updates with added image', () async {
      when(() => dataSource.getHive('hive-1')).thenAnswer((_) async => hiveResponse1);
      when(() => dataSource.updateHive('hive-1', any())).thenAnswer((_) async => hiveResponse1);

      final result = await repository.addHiveImage(hiveId: 'hive-1', mediaId: 'media-2');

      expect(result.isRight, isTrue);
      final captured = verify(() => dataSource.updateHive('hive-1', captureAny())).captured;
      final request = captured.first as HiveRequest;
      expect(request.images, containsAll(['media-1', 'media-2']));
    });
  });

  group('removeHiveImage', () {
    test('fetches current hive and updates with image removed', () async {
      when(() => dataSource.getHive('hive-1')).thenAnswer((_) async => hiveResponse1);
      when(() => dataSource.updateHive('hive-1', any())).thenAnswer((_) async => hiveResponse1);

      final result = await repository.removeHiveImage(hiveId: 'hive-1', mediaId: 'media-1');

      expect(result.isRight, isTrue);
      final captured = verify(() => dataSource.updateHive('hive-1', captureAny())).captured;
      final request = captured.first as HiveRequest;
      expect(request.images, isEmpty);
    });
  });
}
