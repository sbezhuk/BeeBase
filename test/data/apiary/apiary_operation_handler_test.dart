import 'dart:async';

import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
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

class MockOperationQueue extends Mock implements OperationQueue {}

OfflineOperation _createOp({String id = 'op-1', String localEntityId = 'local-1', int version = 0}) {
  return OfflineOperation(
    id: id,
    entityType: 'apiary',
    operationType: OperationType.create,
    payload: const ApiaryRequest(name: 'New Yard', description: 'desc').toJson(),
    status: OperationStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
    version: version,
  );
}

OfflineOperation _updateOp({String id = 'op-2', String localEntityId = 'apiary-1', int version = 0}) {
  return OfflineOperation(
    id: id,
    entityType: 'apiary',
    operationType: OperationType.update,
    payload: const ApiaryRequest(name: 'Renamed').toJson(),
    status: OperationStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
    version: version,
  );
}

void main() {
  late MockApiaryDataSource dataSource;
  late MockApiaryLocalDataSource localDataSource;
  late MockOperationQueue operationQueue;
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
    registerFallbackValue(_createOp());
  });

  setUp(() {
    dataSource = MockApiaryDataSource();
    localDataSource = MockApiaryLocalDataSource();
    operationQueue = MockOperationQueue();
    refreshNotifier = ApiaryListRefreshNotifier();
    handler = ApiaryOperationHandler(
      dataSource: dataSource,
      localDataSource: localDataSource,
      refreshNotifier: refreshNotifier,
      operationQueue: operationQueue,
    );
    when(() => localDataSource.modify(any())).thenAnswer((invocation) async {
      final update = invocation.positionalArguments.single as FutureOr<List<ApiaryResponse>> Function(List<ApiaryResponse>?);
      await update(await localDataSource.read());
    });
    when(() => operationQueue.update(any())).thenAnswer((_) async {});
    // No race by default — most tests aren't exercising the supersede path,
    // and `_checkSupersededAndRetarget` treats "row not found" the same as
    // "nothing changed" (no retarget).
    when(() => operationQueue.find(any())).thenAnswer((_) async => null);
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
      when(
        () => dataSource.createApiary(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenAnswer((_) async => serverResponse);

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationSuccess>());
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<ApiaryResponse>> Function(List<ApiaryResponse>?);
      final written = await update([placeholder]);
      expect(written.map((response) => response.id), ['server-42']);
    });

    test('passes the operation id as the idempotency key', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
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
      verifyNever(() => localDataSource.modify(any()));
    });

    test('classifies an InternalException as a retryable failure', () async {
      when(
        () => dataSource.createApiary(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationRetryableFailure>());
    });

    test('retargets to a pending UPDATE and reports superseded when a newer edit landed mid-flight', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(
        () => dataSource.createApiary(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).thenAnswer((_) async => serverResponse);
      final sent = _createOp();
      final racedRow = _createOp(version: 1).copyWith(payload: const ApiaryRequest(name: 'Newer Edit').toJson());
      when(() => operationQueue.find(sent.id)).thenAnswer((_) async => racedRow);

      final result = await handler.handle(sent);

      expect(result, isA<OperationSuperseded>());
      final retargeted = verify(() => operationQueue.update(captureAny())).captured.single as OfflineOperation;
      expect(retargeted.operationType, OperationType.update);
      expect(retargeted.localEntityId, 'server-42');
      expect(retargeted.status, OperationStatus.pending);
      expect(ApiaryRequest.fromJson(retargeted.payload).name, 'Newer Edit');

      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<ApiaryResponse>> Function(List<ApiaryResponse>?);
      final written = await update([]);
      expect(written.single.id, 'server-42');
      expect(written.single.name, 'Newer Edit');
    });
  });

  group('update', () {
    test('reconciles the cache with the server response and reports success', () async {
      final existing = ApiaryResponse(id: 'apiary-1', name: 'Old Name', createdAt: DateTime(2026), updatedAt: DateTime(2026));
      final updatedResponse = ApiaryResponse(id: 'apiary-1', name: 'Renamed', createdAt: DateTime(2026), updatedAt: DateTime(2026));
      when(() => localDataSource.read()).thenAnswer((_) async => [existing]);
      when(() => dataSource.updateApiary('apiary-1', any())).thenAnswer((_) async => updatedResponse);

      final result = await handler.handle(_updateOp());

      expect(result, isA<OperationSuccess>());
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<ApiaryResponse>> Function(List<ApiaryResponse>?);
      final written = await update([existing]);
      expect(written.single.name, 'Renamed');
    });

    test('classifies a ServerException as a permanent failure', () async {
      when(
        () => dataSource.updateApiary(any(), any()),
      ).thenThrow(const ServerException(statusCode: 422, code: 'validation_error', message: 'invalid'));

      final result = await handler.handle(_updateOp());

      expect(result, isA<OperationPermanentFailure>());
      verifyNever(() => localDataSource.modify(any()));
    });

    test('classifies an InternalException as a retryable failure', () async {
      when(() => dataSource.updateApiary(any(), any())).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await handler.handle(_updateOp());

      expect(result, isA<OperationRetryableFailure>());
    });

    test('reports superseded and keeps it pending when a newer edit landed mid-flight', () async {
      final updatedResponse = ApiaryResponse(id: 'apiary-1', name: 'Renamed', createdAt: DateTime(2026), updatedAt: DateTime(2026));
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(() => dataSource.updateApiary('apiary-1', any())).thenAnswer((_) async => updatedResponse);
      final sent = _updateOp();
      final racedRow = _updateOp(version: 1).copyWith(payload: const ApiaryRequest(name: 'Even Newer').toJson());
      when(() => operationQueue.find(sent.id)).thenAnswer((_) async => racedRow);

      final result = await handler.handle(sent);

      expect(result, isA<OperationSuperseded>());
      final retargeted = verify(() => operationQueue.update(captureAny())).captured.single as OfflineOperation;
      expect(retargeted.localEntityId, 'apiary-1');
      expect(retargeted.status, OperationStatus.pending);
      expect(ApiaryRequest.fromJson(retargeted.payload).name, 'Even Newer');
    });

    test('missing a target id is a permanent failure', () async {
      final orphanOp = OfflineOperation(
        id: 'op-2',
        entityType: 'apiary',
        operationType: OperationType.update,
        payload: const ApiaryRequest(name: 'Renamed').toJson(),
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final result = await handler.handle(orphanOp);

      expect(result, isA<OperationPermanentFailure>());
      verifyNever(() => dataSource.updateApiary(any(), any()));
    });
  });

  test('delete operations are not supported yet', () async {
    final deleteOp = OfflineOperation(
      id: 'op-3',
      entityType: 'apiary',
      operationType: OperationType.delete,
      payload: const {},
      status: OperationStatus.pending,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final result = await handler.handle(deleteOp);

    expect(result, isA<OperationPermanentFailure>());
  });
}
