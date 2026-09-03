import 'dart:async';

import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_handler.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_registry.dart';
import 'package:beebase/core/offline/operation_result.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/offline/sync_engine_impl.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOperationQueue extends Mock implements OperationQueue {}

class MockOperationHandler extends Mock implements OperationHandler {}

class MockConnectivityService extends Mock implements IConnectivityService {}

OfflineOperation _pendingOp({
  String id = 'op-1',
  int retryCount = 0,
  OperationStatus status = OperationStatus.pending,
  String? dependsOnOperationId,
}) {
  return OfflineOperation(
    id: id,
    entityType: 'apiary',
    operationType: OperationType.create,
    payload: const {'name': 'Test'},
    status: status,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    retryCount: retryCount,
    localEntityId: 'local-1',
    dependsOnOperationId: dependsOnOperationId,
  );
}

void main() {
  late MockOperationQueue queue;
  late MockOperationHandler handler;
  late MockConnectivityService connectivity;
  late OperationRegistry registry;
  late SyncEngineImpl engine;

  setUpAll(() {
    registerFallbackValue(_pendingOp());
  });

  setUp(() {
    queue = MockOperationQueue();
    handler = MockOperationHandler();
    connectivity = MockConnectivityService();
    when(() => handler.entityType).thenReturn('apiary');
    registry = OperationRegistry({'apiary': handler});
    engine = SyncEngineImpl(
      queue: queue,
      registry: registry,
      connectivity: connectivity,
    );
    when(() => connectivity.isOnline).thenAnswer((_) async => true);
    when(() => connectivity.status).thenAnswer((_) => const Stream.empty());
    when(() => queue.changes).thenAnswer((_) => const Stream.empty());
    when(() => queue.all()).thenAnswer((_) async => []);
    when(() => queue.update(any())).thenAnswer((_) async {});
    when(() => queue.find(any())).thenAnswer((_) async => null);
    // Default so tests that don't care about sync outcome (e.g. availability-
    // only assertions) don't hit an un-stubbed call when refreshAvailability's
    // reconnect detection auto-triggers a sync in the background.
    when(
      () => handler.handle(any()),
    ).thenAnswer((_) async => const OperationSuccess());
  });

  group('syncNow', () {
    test('does nothing when offline', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);

      await engine.syncNow();

      verifyNever(() => queue.all());
    });

    test('marks a successful operation synced', () async {
      when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
      when(
        () => handler.handle(any()),
      ).thenAnswer((_) async => const OperationSuccess());

      await engine.syncNow();

      final updates = verify(
        () => queue.update(captureAny()),
      ).captured.cast<OfflineOperation>();
      expect(updates.map((op) => op.status), [
        OperationStatus.inProgress,
        OperationStatus.synced,
      ]);
    });

    test(
      'marks a retryable failure failed and bumps retryCount (no auto-retry loop exists anymore)',
      () async {
        when(
          () => queue.all(),
        ).thenAnswer((_) async => [_pendingOp(retryCount: 0)]);
        when(
          () => handler.handle(any()),
        ).thenAnswer((_) async => const OperationRetryableFailure('timeout'));

        await engine.syncNow();

        final updates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>();
        final finalUpdate = updates.last;
        expect(finalUpdate.status, OperationStatus.failed);
        expect(finalUpdate.retryCount, 1);
        expect(finalUpdate.lastError, 'timeout');
      },
    );

    test(
      'marks a permanent failure failed and still bumps retryCount for observability',
      () async {
        when(
          () => queue.all(),
        ).thenAnswer((_) async => [_pendingOp(retryCount: 0)]);
        when(() => handler.handle(any())).thenAnswer(
          (_) async => const OperationPermanentFailure('validation failed'),
        );

        await engine.syncNow();

        final updates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>();
        expect(updates.last.status, OperationStatus.failed);
        expect(updates.last.retryCount, 1);
        expect(updates.last.lastError, 'validation failed');
      },
    );

    test(
      're-processes an already-failed operation — every sync is user-initiated now, no retry cap',
      () async {
        when(() => queue.all()).thenAnswer(
          (_) async => [
            _pendingOp(retryCount: 9, status: OperationStatus.failed),
          ],
        );
        when(
          () => handler.handle(any()),
        ).thenAnswer((_) async => const OperationSuccess());

        await engine.syncNow();

        final updates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>();
        expect(updates.last.status, OperationStatus.synced);
      },
    );

    test(
      'skips an operation whose entity type has no registered handler',
      () async {
        final orphanOp = OfflineOperation(
          id: 'op-2',
          entityType: 'hive',
          operationType: OperationType.create,
          payload: const {},
          status: OperationStatus.pending,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        when(() => queue.all()).thenAnswer((_) async => [orphanOp]);

        await engine.syncNow();

        verifyNever(() => queue.update(any()));
        verifyNever(() => handler.handle(any()));
      },
    );

    test('ignores a synced operation', () async {
      when(
        () => queue.all(),
      ).thenAnswer((_) async => [_pendingOp(status: OperationStatus.synced)]);

      await engine.syncNow();

      verifyNever(() => handler.handle(any()));
    });

    test(
      'a plain success result is a no-op on the queue for OperationSuperseded',
      () async {
        when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
        when(
          () => handler.handle(any()),
        ).thenAnswer((_) async => const OperationSuperseded());

        await engine.syncNow();

        final updates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>();
        // Only the initial inProgress mark — the handler already left the row
        // in the state it wants (re-targeted and pending), so the engine must
        // not additionally mark it synced.
        expect(updates.map((op) => op.status), [OperationStatus.inProgress]);
      },
    );

    test(
      'marks a successful create synced with its resolvedEntityId',
      () async {
        when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
        when(() => handler.handle(any())).thenAnswer(
          (_) async => const OperationSuccess(resolvedEntityId: 'server-9'),
        );

        await engine.syncNow();

        final updates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>();
        expect(updates.last.status, OperationStatus.synced);
        expect(updates.last.resolvedEntityId, 'server-9');
      },
    );

    test(
      'does not dispatch an operation whose dependency has not synced yet',
      () async {
        final dependency = _pendingOp(
          id: 'op-0',
          status: OperationStatus.pending,
        );
        final dependent = _pendingOp(id: 'op-1', dependsOnOperationId: 'op-0');
        when(() => queue.all()).thenAnswer((_) async => [dependent]);
        when(() => queue.find('op-0')).thenAnswer((_) async => dependency);

        await engine.syncNow();

        verifyNever(() => handler.handle(any()));
        verifyNever(() => queue.update(any()));
      },
    );

    test(
      'does not dispatch an operation whose dependency no longer exists',
      () async {
        final dependent = _pendingOp(id: 'op-1', dependsOnOperationId: 'op-0');
        when(() => queue.all()).thenAnswer((_) async => [dependent]);
        when(() => queue.find('op-0')).thenAnswer((_) async => null);

        await engine.syncNow();

        verifyNever(() => handler.handle(any()));
        verifyNever(() => queue.update(any()));
      },
    );

    test(
      'dispatches an operation once its dependency has synced, within the same drain',
      () async {
        final dependency = _pendingOp(
          id: 'op-0',
          status: OperationStatus.synced,
          dependsOnOperationId: null,
        );
        final dependent = _pendingOp(id: 'op-1', dependsOnOperationId: 'op-0');
        when(() => queue.all()).thenAnswer((_) async => [dependent]);
        when(() => queue.find('op-0')).thenAnswer((_) async => dependency);
        when(
          () => handler.handle(any()),
        ).thenAnswer((_) async => const OperationSuccess());

        await engine.syncNow();

        final updates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>();
        expect(updates.map((op) => op.status), [
          OperationStatus.inProgress,
          OperationStatus.synced,
        ]);
      },
    );

    test(
      'a handler throwing (not returning an OperationResult) is caught and marks the operation failed instead of stranding it in progress',
      () async {
        when(
          () => queue.all(),
        ).thenAnswer((_) async => [_pendingOp(retryCount: 0)]);
        when(
          () => handler.handle(any()),
        ).thenThrow(const FormatException('bad mime type'));

        await engine.syncNow();

        final updates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>();
        expect(updates.map((op) => op.status), [
          OperationStatus.inProgress,
          OperationStatus.failed,
        ]);
        expect(updates.last.retryCount, 1);
        expect(updates.last.lastError, contains('bad mime type'));
      },
    );

    test(
      'a handler throwing for one operation does not abort the rest of the batch',
      () async {
        final first = _pendingOp(id: 'op-1');
        final second = _pendingOp(id: 'op-2');
        when(() => queue.all()).thenAnswer((_) async => [first, second]);
        when(() => queue.find('op-1')).thenAnswer((_) async => first);
        when(() => queue.find('op-2')).thenAnswer((_) async => second);
        when(() => handler.handle(first)).thenThrow(Exception('missing file'));
        when(
          () => handler.handle(second),
        ).thenAnswer((_) async => const OperationSuccess());

        await engine.syncNow();

        final updates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>();
        expect(updates.where((op) => op.id == 'op-1').map((op) => op.status), [
          OperationStatus.inProgress,
          OperationStatus.failed,
        ]);
        expect(updates.where((op) => op.id == 'op-2').map((op) => op.status), [
          OperationStatus.inProgress,
          OperationStatus.synced,
        ]);
      },
    );

    test(
      'a handler that already marked its row synced before throwing (e.g. a post-success notify failing) '
      'is not downgraded back to failed',
      () async {
        final op = _pendingOp(id: 'op-1');
        when(() => queue.all()).thenAnswer((_) async => [op]);
        // Simulates a handler whose own `_markSynced` write already landed
        // (see `ApiaryOperationHandler._markSynced`) before some later,
        // non-essential step — e.g. `refreshNotifier.notify()` — threw.
        when(() => queue.find('op-1')).thenAnswer(
          (_) async => op.copyWith(
            status: OperationStatus.synced,
            resolvedEntityId: 'server-1',
          ),
        );
        when(
          () => handler.handle(any()),
        ).thenThrow(Exception('notifier blew up after the write'));

        await engine.syncNow();

        final updates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>();
        // Only the initial `inProgress` mark from `_process` itself — no
        // `failed` write follows, since the row was already `synced` by the
        // time the exception was caught.
        expect(updates.map((op) => op.status), [OperationStatus.inProgress]);
      },
    );

    test(
      'a bookkeeping write throwing after a successful result does not abort the rest of the batch',
      () async {
        final first = _pendingOp(id: 'op-1');
        final second = _pendingOp(id: 'op-2');
        when(() => queue.all()).thenAnswer((_) async => [first, second]);
        when(() => queue.find('op-1')).thenAnswer((_) async => first);
        when(() => queue.find('op-2')).thenAnswer((_) async => second);
        when(
          () => handler.handle(any()),
        ).thenAnswer((_) async => const OperationSuccess());
        when(
          () => queue.update(
            any(
              that: isA<OfflineOperation>()
                  .having((op) => op.id, 'id', 'op-1')
                  .having((op) => op.status, 'status', OperationStatus.synced),
            ),
          ),
        ).thenThrow(Exception('database is locked'));

        await engine.syncNow();

        final secondUpdates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>().where((op) => op.id == 'op-2');
        expect(secondUpdates.map((op) => op.status), [
          OperationStatus.inProgress,
          OperationStatus.synced,
        ]);
      },
    );

    test(
      'a failure does not clobber a payload that changed while the request was in flight',
      () async {
        final sent = _pendingOp(id: 'op-1');
        when(() => queue.all()).thenAnswer((_) async => [sent]);
        final mutatedMidFlight = sent.copyWith(
          payload: const {'name': 'Edited While In Flight'},
          version: 1,
        );
        when(
          () => queue.find('op-1'),
        ).thenAnswer((_) async => mutatedMidFlight);
        when(
          () => handler.handle(any()),
        ).thenAnswer((_) async => const OperationRetryableFailure('timeout'));

        await engine.syncNow();

        final finalUpdate = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>().last;
        expect(finalUpdate.status, OperationStatus.failed);
        expect(finalUpdate.payload, {'name': 'Edited While In Flight'});
        expect(finalUpdate.version, 1);
      },
    );
  });

  group(
    'syncNow in-pass retry (self-healing without a new connectivity event or app restart)',
    () {
      late SyncEngineImpl retryingEngine;

      setUp(() {
        // Zero delay so these tests don't wait on the real clock — behavior
        // under test is the retry *happening*, not its timing.
        retryingEngine = SyncEngineImpl(
          queue: queue,
          registry: registry,
          connectivity: connectivity,
          retryDelay: Duration.zero,
        );
      });

      test(
        'retries an operation that is still failing after its first attempt, within the same call',
        () async {
          final op = _pendingOp(id: 'op-1');
          when(() => queue.all()).thenAnswer((_) async => [op]);
          var attempts = 0;
          when(() => handler.handle(any())).thenAnswer((_) async {
            attempts++;
            return attempts == 1
                ? const OperationRetryableFailure(
                    'transient blip right at reconnect',
                  )
                : const OperationSuccess();
          });
          when(() => queue.find('op-1')).thenAnswer((_) async {
            if (attempts == 0) return op;
            return op.copyWith(
              status: attempts == 1
                  ? OperationStatus.failed
                  : OperationStatus.synced,
              retryCount: attempts == 1 ? 1 : 0,
            );
          });

          await retryingEngine.syncNow();

          verify(() => handler.handle(any())).called(2);
        },
      );

      test(
        'gives up after the max in-pass attempts and leaves the operation failed for the next external trigger',
        () async {
          final op = _pendingOp(id: 'op-1');
          when(() => queue.all()).thenAnswer((_) async => [op]);
          when(() => handler.handle(any())).thenAnswer(
            (_) async => const OperationRetryableFailure('still down'),
          );
          when(() => queue.find('op-1')).thenAnswer(
            (_) async =>
                op.copyWith(status: OperationStatus.failed, retryCount: 1),
          );

          await retryingEngine.syncNow();

          // 3 attempts total (the configured cap), never more.
          verify(() => handler.handle(any())).called(3);
        },
      );

      test(
        'stops retrying if connectivity is lost mid-sync instead of spinning offline',
        () async {
          final op = _pendingOp(id: 'op-1');
          when(() => queue.all()).thenAnswer((_) async => [op]);
          when(
            () => handler.handle(any()),
          ).thenAnswer((_) async => const OperationRetryableFailure('timeout'));
          when(() => queue.find('op-1')).thenAnswer(
            (_) async =>
                op.copyWith(status: OperationStatus.failed, retryCount: 1),
          );
          var onlineChecks = 0;
          when(() => connectivity.isOnline).thenAnswer((_) async {
            onlineChecks++;
            // Online for the initial syncNow() guard and the first attempt,
            // offline by the time the retry loop checks before its next pass.
            return onlineChecks <= 1;
          });

          await retryingEngine.syncNow();

          verify(() => handler.handle(any())).called(1);
        },
      );
    },
  );

  group('syncAvailable / start / refreshAvailability', () {
    test('is false before start() and while offline', () async {
      expect(engine.syncAvailable.value, isFalse);
    });

    test(
      'refreshAvailability sets true when online with a pending operation',
      () async {
        when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);

        await engine.refreshAvailability();

        expect(engine.syncAvailable.value, isTrue);
      },
    );

    test(
      'refreshAvailability is false when offline even with pending operations',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);
        when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);

        await engine.refreshAvailability();

        expect(engine.syncAvailable.value, isFalse);
      },
    );

    test(
      'refreshAvailability is false when online with nothing pending or failed',
      () async {
        when(
          () => queue.all(),
        ).thenAnswer((_) async => [_pendingOp(status: OperationStatus.synced)]);

        await engine.refreshAvailability();

        expect(engine.syncAvailable.value, isFalse);
      },
    );

    test(
      'a failed operation also counts as available (so the user can retry it)',
      () async {
        when(
          () => queue.all(),
        ).thenAnswer((_) async => [_pendingOp(status: OperationStatus.failed)]);

        await engine.refreshAvailability();

        expect(engine.syncAvailable.value, isTrue);
      },
    );

    test(
      'a row stuck in progress (e.g. stranded before the handler-exception fix, or by an app kill mid-request) also counts as available',
      () async {
        when(() => queue.all()).thenAnswer(
          (_) async => [_pendingOp(status: OperationStatus.inProgress)],
        );

        await engine.refreshAvailability();

        expect(engine.syncAvailable.value, isTrue);
      },
    );

    test(
      'start() automatically triggers syncNow when connectivity transitions from offline to online',
      () async {
        final statusController = StreamController<bool>();
        var online = false;
        when(
          () => connectivity.status,
        ).thenAnswer((_) => statusController.stream);
        when(() => connectivity.isOnline).thenAnswer((_) async => online);
        when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
        when(
          () => handler.handle(any()),
        ).thenAnswer((_) async => const OperationSuccess());

        engine.start();
        await Future<void>.delayed(Duration.zero);

        expect(engine.syncAvailable.value, isFalse);
        verifyNever(() => handler.handle(any()));

        online = true;
        statusController.add(true);
        await Future<void>.delayed(Duration.zero);

        verify(() => handler.handle(any())).called(1);
        final updates = verify(
          () => queue.update(captureAny()),
        ).captured.cast<OfflineOperation>();
        expect(updates.map((op) => op.status), [
          OperationStatus.inProgress,
          OperationStatus.synced,
        ]);

        await statusController.close();
      },
    );

    test(
      'start() does not re-trigger syncNow on a connectivity event that stays online',
      () async {
        final statusController = StreamController<bool>();
        when(
          () => connectivity.status,
        ).thenAnswer((_) => statusController.stream);
        when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
        when(
          () => handler.handle(any()),
        ).thenAnswer((_) async => const OperationSuccess());

        engine.start();
        await Future<void>.delayed(Duration.zero);
        verify(() => handler.handle(any())).called(1);

        // Already online (connectivity.isOnline defaults to true in setUp) —
        // a further "online" event from the stream (e.g. switching wifi
        // networks without ever going offline) must not fire another sync.
        statusController.add(true);
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => handler.handle(any()));

        await statusController.close();
      },
    );

    test(
      'refreshAvailability() auto-syncs on a cold start that is already online with leftover pending operations',
      () async {
        when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
        when(
          () => handler.handle(any()),
        ).thenAnswer((_) async => const OperationSuccess());

        await engine.refreshAvailability();

        verify(() => handler.handle(any())).called(1);
      },
    );

    test(
      'start() reacts to the queue changing (a new operation enqueued while already online)',
      () async {
        final changesController = StreamController<void>();
        when(() => queue.changes).thenAnswer((_) => changesController.stream);
        when(() => queue.all()).thenAnswer((_) async => []);

        engine.start();
        await Future<void>.delayed(Duration.zero);
        expect(engine.syncAvailable.value, isFalse);

        when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);
        changesController.add(null);
        await Future<void>.delayed(Duration.zero);

        expect(engine.syncAvailable.value, isTrue);

        await changesController.close();
      },
    );
  });

  group('hasPendingOperations', () {
    test('is false before start() and when nothing is queued', () async {
      expect(engine.hasPendingOperations.value, isFalse);
    });

    test(
      'is true offline with a pending operation, unlike syncAvailable',
      () async {
        when(() => connectivity.isOnline).thenAnswer((_) async => false);
        when(() => queue.all()).thenAnswer((_) async => [_pendingOp()]);

        await engine.refreshAvailability();

        expect(engine.hasPendingOperations.value, isTrue);
        expect(engine.syncAvailable.value, isFalse);
      },
    );

    test('a failed operation also counts as pending', () async {
      when(() => connectivity.isOnline).thenAnswer((_) async => false);
      when(
        () => queue.all(),
      ).thenAnswer((_) async => [_pendingOp(status: OperationStatus.failed)]);

      await engine.refreshAvailability();

      expect(engine.hasPendingOperations.value, isTrue);
    });

    test('is false when everything is synced, online or off', () async {
      when(
        () => queue.all(),
      ).thenAnswer((_) async => [_pendingOp(status: OperationStatus.synced)]);

      await engine.refreshAvailability();

      expect(engine.hasPendingOperations.value, isFalse);
    });
  });
}
