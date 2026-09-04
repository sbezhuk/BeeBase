import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/entity_image_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryDataSource extends Mock implements IApiaryDataSource {}

void main() {
  late MockApiaryDataSource dataSource;
  late ApiaryRepositoryImpl repository;

  final apiaryResponse = ApiaryResponse(
    id: 'apiary-1',
    name: 'Back Garden',
    description: 'A small apiary',
    location: 'Springfield',
    lat: 50.0,
    lon: 30.0,
    images: const [
      EntityImageResponse(
        id: 'media-1',
        imageUrl: 'https://api.beebase.test/api/v1/media/media-1/download',
      ),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );

  setUpAll(() {
    registerFallbackValue(const ApiaryRequest(name: 'fallback'));
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
  });

  setUp(() {
    dataSource = MockApiaryDataSource();
    repository = ApiaryRepositoryImpl(dataSource: dataSource);
  });

  group('getApiaries', () {
    test('returns mapped Page<Apiary> on success', () async {
      when(() => dataSource.getApiaries(any())).thenAnswer(
        (_) async => PaginatedResponse(
          items: [apiaryResponse],
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

      final result = await repository.getApiaries(page: 1, limit: 20);

      result.fold(
        (_) => fail('expected Right'),
        (page) {
          expect(page.items.length, 1);
          expect(page.items.first.id, 'apiary-1');
          expect(page.items.first.name, 'Back Garden');
          expect(page.hasNext, false);
        },
      );
    });

    test('returns ServerFailure when dataSource throws ServerException', () async {
      when(() => dataSource.getApiaries(any())).thenThrow(
        const ServerException(statusCode: 500, code: 'error', message: 'failed'),
      );

      final result = await repository.getApiaries(page: 1, limit: 20);

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('getApiary', () {
    test('returns mapped Apiary on success', () async {
      when(() => dataSource.getApiary('apiary-1')).thenAnswer((_) async => apiaryResponse);

      final result = await repository.getApiary('apiary-1');

      result.fold(
        (_) => fail('expected Right'),
        (apiary) {
          expect(apiary.id, 'apiary-1');
          expect(apiary.name, 'Back Garden');
        },
      );
    });

    test('returns ServerFailure when dataSource throws', () async {
      when(() => dataSource.getApiary('apiary-1')).thenThrow(
        const ServerException(statusCode: 404, code: 'not_found', message: 'Not found'),
      );

      final result = await repository.getApiary('apiary-1');

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('createApiary', () {
    test('calls dataSource.createApiary and returns mapped Apiary', () async {
      when(() => dataSource.createApiary(any())).thenAnswer((_) async => apiaryResponse);

      final result = await repository.createApiary(
        name: 'Back Garden',
        description: 'A small apiary',
        location: 'Springfield',
        lat: 50.0,
        lon: 30.0,
      );

      result.fold(
        (_) => fail('expected Right'),
        (apiary) => expect(apiary.id, 'apiary-1'),
      );
      verify(() => dataSource.createApiary(any())).called(1);
    });
  });

  group('updateApiary', () {
    test('calls dataSource.updateApiary and returns mapped Apiary', () async {
      when(() => dataSource.updateApiary('apiary-1', any())).thenAnswer((_) async => apiaryResponse);

      final result = await repository.updateApiary(
        id: 'apiary-1',
        name: 'Back Garden',
        description: 'A small apiary',
      );

      result.fold(
        (_) => fail('expected Right'),
        (apiary) => expect(apiary.id, 'apiary-1'),
      );
      verify(() => dataSource.updateApiary('apiary-1', any())).called(1);
    });
  });

  group('addApiaryImage', () {
    test('fetches current apiary and updates with added image', () async {
      when(() => dataSource.getApiary('apiary-1')).thenAnswer((_) async => apiaryResponse);
      when(() => dataSource.updateApiary('apiary-1', any())).thenAnswer((_) async => apiaryResponse);

      final result = await repository.addApiaryImage(apiaryId: 'apiary-1', mediaId: 'media-2');

      expect(result.isRight, isTrue);
      final captured = verify(() => dataSource.updateApiary('apiary-1', captureAny())).captured;
      final request = captured.first as ApiaryRequest;
      expect(request.images, containsAll(['media-1', 'media-2']));
    });
  });

  group('removeApiaryImage', () {
    test('fetches current apiary and updates with image removed', () async {
      when(() => dataSource.getApiary('apiary-1')).thenAnswer((_) async => apiaryResponse);
      when(() => dataSource.updateApiary('apiary-1', any())).thenAnswer((_) async => apiaryResponse);

      final result = await repository.removeApiaryImage(apiaryId: 'apiary-1', mediaId: 'media-1');

      expect(result.isRight, isTrue);
      final captured = verify(() => dataSource.updateApiary('apiary-1', captureAny())).captured;
      final request = captured.first as ApiaryRequest;
      expect(request.images, isEmpty);
    });

    test('no-op update when mediaId is not in images', () async {
      when(() => dataSource.getApiary('apiary-1')).thenAnswer((_) async => apiaryResponse);

      final result = await repository.removeApiaryImage(apiaryId: 'apiary-1', mediaId: 'non-existent');

      expect(result.isRight, isTrue);
      verifyNever(() => dataSource.updateApiary(any(), any()));
    });
  });

  group('deleteApiary', () {
    test('calls dataSource.deleteApiary', () async {
      when(() => dataSource.deleteApiary('apiary-1')).thenAnswer((_) async {});

      final result = await repository.deleteApiary('apiary-1');

      expect(result.isRight, isTrue);
      verify(() => dataSource.deleteApiary('apiary-1')).called(1);
    });

    test('treats 404 as successful delete', () async {
      when(() => dataSource.deleteApiary('apiary-1')).thenThrow(
        const ServerException(statusCode: 404, code: 'not_found', message: 'Not found'),
      );

      final result = await repository.deleteApiary('apiary-1');

      expect(result.isRight, isTrue);
    });
  });
}
