import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/repositories/apiary_repository_impl.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryDataSource extends Mock implements IApiaryDataSource {}

void main() {
  late MockApiaryDataSource dataSource;
  late ApiaryRepositoryImpl repository;

  final apiaryResponse = ApiaryResponse(
    id: 'apiary-1',
    name: 'Back Garden',
    notes: 'A small apiary',
    location: 'Springfield',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(const ApiaryRequest(name: 'fallback'));
  });

  setUp(() {
    dataSource = MockApiaryDataSource();
    repository = ApiaryRepositoryImpl(dataSource: dataSource);
  });

  group('getApiaries', () {
    test('returns the mapped list on success', () async {
      when(() => dataSource.getApiaries()).thenAnswer((_) async => [apiaryResponse]);

      final result = await repository.getApiaries();

      result.fold((_) => fail('expected Right'), (apiaries) => expect(apiaries.single.name, 'Back Garden'));
    });

    test('maps a thrown exception to a Failure', () async {
      when(() => dataSource.getApiaries()).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.getApiaries();

      expect(result, isA<Left<Failure, dynamic>>());
    });
  });

  group('getApiary', () {
    test('returns the mapped apiary on success', () async {
      when(() => dataSource.getApiary('apiary-1')).thenAnswer((_) async => apiaryResponse);

      final result = await repository.getApiary('apiary-1');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.id, 'apiary-1'));
    });
  });

  group('createApiary', () {
    test('sends the request and returns the mapped apiary', () async {
      when(() => dataSource.createApiary(any())).thenAnswer((_) async => apiaryResponse);

      final result = await repository.createApiary(name: 'Back Garden', description: 'A small apiary', location: 'Springfield');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.name, 'Back Garden'));
      final captured = verify(() => dataSource.createApiary(captureAny())).captured.single as ApiaryRequest;
      expect(captured.name, 'Back Garden');
    });

    test('maps a validation error to a ServerFailure', () async {
      when(() => dataSource.createApiary(any())).thenThrow(
        const ServerException(statusCode: 422, code: 'validation_error', message: 'invalid', fields: {'name': 'name_required'}),
      );

      final result = await repository.createApiary(name: '');

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>().having((f) => f.code, 'code', 'validation_error')),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateApiary', () {
    test('sends the request and returns the mapped apiary', () async {
      when(() => dataSource.updateApiary('apiary-1', any())).thenAnswer((_) async => apiaryResponse);

      final result = await repository.updateApiary(id: 'apiary-1', name: 'Back Garden');

      result.fold((_) => fail('expected Right'), (apiary) => expect(apiary.id, 'apiary-1'));
    });
  });

  group('deleteApiary', () {
    test('completes with Right on success', () async {
      when(() => dataSource.deleteApiary('apiary-1')).thenAnswer((_) async {});

      final result = await repository.deleteApiary('apiary-1');

      expect(result, isA<Right<Failure, void>>());
    });

    test('maps a thrown exception to a Failure', () async {
      when(() => dataSource.deleteApiary('apiary-1')).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await repository.deleteApiary('apiary-1');

      expect(result, isA<Left<Failure, void>>());
    });
  });
}
