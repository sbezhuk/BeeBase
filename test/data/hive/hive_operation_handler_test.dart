import 'dart:async';

import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/hive/hive_operation_handler.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveDataSource extends Mock implements IHiveDataSource {}

class MockHiveLocalDataSource extends Mock implements LocalDataSource<List<HiveResponse>> {}

class MockOperationQueue extends Mock implements OperationQueue {}

OfflineOperation _createOp({String id = 'op-1', String localEntityId = 'local-1', int version = 0}) {
  return OfflineOperation(
    id: id,
    entityType: 'hive',
    operationType: OperationType.create,
    payload: {
      'apiaryId': 'apiary-1',
      ...const HiveRequest(name: 'New Hive', notes: 'desc').toJson(),
    },
    status: OperationStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
    version: version,
  );
}

OfflineOperation _updateOp({String id = 'op-2', String localEntityId = 'hive-1', int version = 0}) {
  return OfflineOperation(
    id: id,
    entityType: 'hive',
    operationType: OperationType.update,
    payload: {
      'apiaryId': 'apiary-1',
      ...const HiveRequest(name: 'Renamed').toJson(),
    },
    status: OperationStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    localEntityId: localEntityId,
    version: version,
  );
}

void main() {
  late MockHiveDataSource dataSource;
  late MockHiveLocalDataSource localDataSource;
  late MockOperationQueue operationQueue;
  late HiveListRefreshNotifier refreshNotifier;
  late HiveOperationHandler handler;

  final serverResponse = HiveResponse(
    id: 'server-42',
    apiaryId: 'apiary-1',
    name: 'New Hive',
    notes: 'desc',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(const HiveRequest(name: 'fallback'));
    registerFallbackValue(_createOp());
  });

  setUp(() {
    dataSource = MockHiveDataSource();
    localDataSource = MockHiveLocalDataSource();
    operationQueue = MockOperationQueue();
    refreshNotifier = HiveListRefreshNotifier();
    handler = HiveOperationHandler(
      dataSource: dataSource,
      localDataSource: localDataSource,
      refreshNotifier: refreshNotifier,
      operationQueue: operationQueue,
    );
    when(() => localDataSource.modify(any())).thenAnswer((invocation) async {
      final update = invocation.positionalArguments.single as FutureOr<List<HiveResponse>> Function(List<HiveResponse>?);
      await update(await localDataSource.read());
    });
    when(() => operationQueue.update(any())).thenAnswer((_) async {});
    when(() => operationQueue.find(any())).thenAnswer((_) async => null);
  });

  tearDown(() => refreshNotifier.dispose());

  test('entityType is hive', () {
    expect(handler.entityType, 'hive');
  });

  group('create', () {
    test('reads the apiary id from the payload and reconciles the cache on success', () async {
      final placeholder = HiveResponse(
        id: 'local-1',
        apiaryId: 'apiary-1',
        name: 'New Hive',
        notes: 'desc',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => [placeholder]);
      when(
        () => dataSource.createHive(
          any(),
          apiaryId: 'apiary-1',
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => serverResponse);

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationSuccess>());
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<HiveResponse>> Function(List<HiveResponse>?);
      final written = await update([placeholder]);
      expect(written.map((response) => response.id), ['server-42']);
    });

    test('passes the operation id as the idempotency key', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(
        () => dataSource.createHive(
          any(),
          apiaryId: any(named: 'apiaryId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => serverResponse);

      await handler.handle(_createOp(id: 'op-99'));

      verify(() => dataSource.createHive(any(), apiaryId: 'apiary-1', idempotencyKey: 'op-99')).called(1);
    });

    test('classifies a ServerException as a permanent failure', () async {
      when(
        () => dataSource.createHive(
          any(),
          apiaryId: any(named: 'apiaryId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(const ServerException(statusCode: 422, code: 'validation_error', message: 'invalid'));

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationPermanentFailure>());
      verifyNever(() => localDataSource.modify(any()));
    });

    test('classifies an InternalException as a retryable failure', () async {
      when(
        () => dataSource.createHive(
          any(),
          apiaryId: any(named: 'apiaryId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(const InternalException(ErrorTextRaw('no connection')));

      final result = await handler.handle(_createOp());

      expect(result, isA<OperationRetryableFailure>());
    });

    test('retargets to a pending UPDATE and reports superseded when a newer edit landed mid-flight', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(
        () => dataSource.createHive(
          any(),
          apiaryId: any(named: 'apiaryId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => serverResponse);
      final sent = _createOp();
      final racedRow = _createOp(version: 1).copyWith(
        payload: {
          'apiaryId': 'apiary-1',
          ...const HiveRequest(name: 'Newer Edit').toJson(),
        },
      );
      when(() => operationQueue.find(sent.id)).thenAnswer((_) async => racedRow);

      final result = await handler.handle(sent);

      expect(result, isA<OperationSuperseded>());
      final retargeted = verify(() => operationQueue.update(captureAny())).captured.single as OfflineOperation;
      expect(retargeted.operationType, OperationType.update);
      expect(retargeted.localEntityId, 'server-42');
      expect(retargeted.status, OperationStatus.pending);

      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<HiveResponse>> Function(List<HiveResponse>?);
      final written = await update([]);
      expect(written.single.id, 'server-42');
      expect(written.single.name, 'Newer Edit');
      expect(written.single.apiaryId, 'apiary-1');
    });

    test('marks the operation synced in the queue before notifying, so a live refresh sees it as already synced', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(
        () => dataSource.createHive(
          any(),
          apiaryId: any(named: 'apiaryId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => serverResponse);

      await handler.handle(_createOp());

      final syncedUpdate = verify(() => operationQueue.update(captureAny())).captured.single as OfflineOperation;
      expect(syncedUpdate.status, OperationStatus.synced);
      expect(syncedUpdate.resolvedEntityId, 'server-42');
    });
  });

  group('create with a still-local parent apiary', () {
    OfflineOperation createOpForLocalApiary({String? dependsOnOperationId}) {
      return OfflineOperation(
        id: 'op-1',
        entityType: 'hive',
        operationType: OperationType.create,
        payload: {
          'apiaryId': 'local-apiary-1',
          ...const HiveRequest(name: 'New Hive', notes: 'desc').toJson(),
        },
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        localEntityId: 'local-1',
        dependsOnOperationId: dependsOnOperationId,
      );
    }

    test('resolves the real apiary id from the synced dependency operation before sending', () async {
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(() => operationQueue.find('apiary-op-1')).thenAnswer(
        (_) async => OfflineOperation(
          id: 'apiary-op-1',
          entityType: 'apiary',
          operationType: OperationType.create,
          payload: const {},
          status: OperationStatus.synced,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          resolvedEntityId: 'server-apiary-9',
        ),
      );
      when(
        () => dataSource.createHive(
          any(),
          apiaryId: any(named: 'apiaryId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => serverResponse);

      final result = await handler.handle(createOpForLocalApiary(dependsOnOperationId: 'apiary-op-1'));

      expect(result, isA<OperationSuccess>());
      verify(() => dataSource.createHive(any(), apiaryId: 'server-apiary-9', idempotencyKey: 'op-1')).called(1);
    });

    test('fails retryably without calling the API when the dependency has not synced yet', () async {
      when(() => operationQueue.find('apiary-op-1')).thenAnswer(
        (_) async => OfflineOperation(
          id: 'apiary-op-1',
          entityType: 'apiary',
          operationType: OperationType.create,
          payload: const {},
          status: OperationStatus.pending,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

      final result = await handler.handle(createOpForLocalApiary(dependsOnOperationId: 'apiary-op-1'));

      expect(result, isA<OperationRetryableFailure>());
      verifyNever(
        () => dataSource.createHive(
          any(),
          apiaryId: any(named: 'apiaryId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    test('fails retryably when there is no dependency operation id at all', () async {
      final result = await handler.handle(createOpForLocalApiary());

      expect(result, isA<OperationRetryableFailure>());
      verifyNever(
        () => dataSource.createHive(
          any(),
          apiaryId: any(named: 'apiaryId'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });
  });

  group('update', () {
    test('reconciles the cache with the server response and reports success', () async {
      final existing = HiveResponse(
        id: 'hive-1',
        apiaryId: 'apiary-1',
        name: 'Old Name',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final updatedResponse = HiveResponse(
        id: 'hive-1',
        apiaryId: 'apiary-1',
        name: 'Renamed',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => [existing]);
      when(() => dataSource.updateHive('hive-1', any())).thenAnswer((_) async => updatedResponse);

      final result = await handler.handle(_updateOp());

      expect(result, isA<OperationSuccess>());
      final update =
          verify(() => localDataSource.modify(captureAny())).captured.single
              as FutureOr<List<HiveResponse>> Function(List<HiveResponse>?);
      final written = await update([existing]);
      expect(written.single.name, 'Renamed');
    });

    test('does not send an apiary id in the update request', () async {
      final updatedResponse = HiveResponse(
        id: 'hive-1',
        apiaryId: 'apiary-1',
        name: 'Renamed',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(() => dataSource.updateHive('hive-1', any())).thenAnswer((_) async => updatedResponse);

      await handler.handle(_updateOp());

      verify(() => dataSource.updateHive('hive-1', any())).called(1);
    });

    test('marks the operation synced in the queue before notifying, so a live refresh sees it as already synced', () async {
      final updatedResponse = HiveResponse(
        id: 'hive-1',
        apiaryId: 'apiary-1',
        name: 'Renamed',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => localDataSource.read()).thenAnswer((_) async => []);
      when(() => dataSource.updateHive('hive-1', any())).thenAnswer((_) async => updatedResponse);

      await handler.handle(_updateOp());

      final syncedUpdate = verify(() => operationQueue.update(captureAny())).captured.single as OfflineOperation;
      expect(syncedUpdate.status, OperationStatus.synced);
    });

    test('classifies a ServerException as a permanent failure', () async {
      when(
        () => dataSource.updateHive(any(), any()),
      ).thenThrow(const ServerException(statusCode: 422, code: 'validation_error', message: 'invalid'));

      final result = await handler.handle(_updateOp());

      expect(result, isA<OperationPermanentFailure>());
      verifyNever(() => localDataSource.modify(any()));
    });

    test('missing a target id is a permanent failure', () async {
      final orphanOp = OfflineOperation(
        id: 'op-2',
        entityType: 'hive',
        operationType: OperationType.update,
        payload: {
          'apiaryId': 'apiary-1',
          ...const HiveRequest(name: 'Renamed').toJson(),
        },
        status: OperationStatus.pending,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final result = await handler.handle(orphanOp);

      expect(result, isA<OperationPermanentFailure>());
      verifyNever(() => dataSource.updateHive(any(), any()));
    });
  });

  test('delete operations are not supported yet', () async {
    final deleteOp = OfflineOperation(
      id: 'op-3',
      entityType: 'hive',
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
