import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/apiary/apiary_operation_handler.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryDataSource extends Mock implements IApiaryDataSource {}

class MockApiaryLocalDataSource extends Mock implements LocalDataSource<List<ApiaryResponse>> {}

OfflineOperation _createOp({String id = 'op-1', String localEntityId = 'local-1'}) {
  return OfflineOperation(
    id: id,
    entityType: 'apiary',
    operationType: OperationType.create,
    payload: const ApiaryRequest(name: 'New Yard', description: 'desc').toJson(),
    status: OperationStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
  );
}

void main() {
  late MockApiaryDataSource dataSource;
  late MockApiaryLocalDataSource localDataSource;
  late ApiaryListRefreshNotifier refreshNotifier;
  late ApiaryOperationHandler handler;

  final serverResponse = ApiaryResponse(
    id: 'server-42',
    name: 'New Yard',
    description: 'desc',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(const ApiaryRequest(name: 'fallback'));
  });

  setUp(() {
    dataSource = MockApiaryDataSource();
    localDataSource = MockApiaryLocalDataSource();
    refreshNotifier = ApiaryListRefreshNotifier();
    handler = ApiaryOperationHandler(dataSource: dataSource, localDataSource: localDataSource, refreshNotifier: refreshNotifier);
  });

  tearDown(() => refreshNotifier.dispose());

  test('entityType is apiary', () {
    expect(handler.entityType, 'apiary');
  });

  group('create', () {
    test('reconciles the cache and reports success', () async {
      final placeholder = ApiaryResponse(
        id: 'local-1',
        name: 'New Yard',
        description: 'desc',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => [placeholder]);
      when(() => localDataSource.write(any())).thenAnswer((_) async {});
      when(
        () => dataSource.createApiary(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenAnswer((_) async => serverResponse);

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationSuccess>());
      final written = verify(() => localDataSource.write(captureAny())).captured.single as List<ApiaryResponse>;
      expect(written.map((response) => response.id), ['server-42']);
    });

    test('passes the operation id as the idempotency key', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(() => localDataSource.write(any())).thenAnswer((_) async {});
      when(
        () => dataSource.createApiary(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenAnswer((_) async => serverResponse);

      await handler.handle(_createOp(id: 'op-99'));

      verify(() => dataSource.createApiary(any(), idempotencyKey: 'op-99')).called(1);
    });

    test('classifies a ServerException as a permanent failure', () async {
      when(
        () => dataSource.createApiary(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenThrow(const ServerException(statusCode: 422, code: 'validation_error', message: 'invalid'));

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationPermanentFailure>());
      verifyNever(() => localDataSource.write(any()));
    });

    test('classifies an InternalException as a retryable failure', () async {
      when(
        () => dataSource.createApiary(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationRetryableFailure>());
    });
  });

  test('update/delete operations are not supported yet', () async {
    final updateOp = OfflineOperation(
      id: 'op-2',
      entityType: 'apiary',
      operationType: OperationType.update,
      payload: const {},
      status: OperationStatus.pending,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final result = await handler.handle(updateOp);

    expect(result, isA<OperationPermanentFailure>());
  });
}
