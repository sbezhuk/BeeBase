import 'package:beebase/core/offline/sync_engine.dart';
import 'package:beebase/presentation/sync/cubit/sync_banner_cubit/sync_banner_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSyncEngine implements SyncEngine {
  final ValueNotifier<bool> _available = ValueNotifier(false);
  final ValueNotifier<bool> _pending = ValueNotifier(false);
  final ValueNotifier<bool> _syncing = ValueNotifier(false);
  int syncNowCallCount = 0;
  Future<void> Function()? onSyncNow;

  @override
  ValueListenable<bool> get syncAvailable => _available;

  @override
  ValueListenable<bool> get hasPendingOperations => _pending;

  @override
  ValueListenable<bool> get isSyncing => _syncing;

  @override
  void start() {}

  @override
  Future<void> refreshAvailability() async {}

  @override
  Future<void> syncNow() async {
    syncNowCallCount++;
    _syncing.value = true;
    try {
      final callback = onSyncNow;
      if (callback != null) {
        await callback();
      }
    } finally {
      _syncing.value = false;
    }
  }

  void setAvailable(bool value) => _available.value = value;

  void setPending(bool value) => _pending.value = value;
}

void main() {
  late _FakeSyncEngine engine;

  setUp(() {
    engine = _FakeSyncEngine();
  });

  test('starts hidden when nothing is available to sync', () {
    final cubit = SyncBannerCubit(engine: engine);

    expect(cubit.state, isA<SyncBannerHidden>());
  });

  test('starts available when the engine already has something to sync', () {
    engine.setAvailable(true);

    final cubit = SyncBannerCubit(engine: engine);

    expect(cubit.state, isA<SyncBannerAvailable>());
  });

  test('mirrors the engine flipping to available', () {
    final cubit = SyncBannerCubit(engine: engine);

    engine.setAvailable(true);

    expect(cubit.state, isA<SyncBannerAvailable>());
  });

  test('mirrors the engine flipping back to hidden', () {
    engine.setAvailable(true);
    final cubit = SyncBannerCubit(engine: engine);

    engine.setAvailable(false);

    expect(cubit.state, isA<SyncBannerHidden>());
  });

  test(
    'sync() emits Syncing for the whole engine.syncNow() call, then reflects the final availability',
    () async {
      engine.setAvailable(true);
      engine.onSyncNow = () async {
        // Mid-flight, driven purely by `isSyncing` staying true — no separate
        // local "syncing" state to fall out of step with it.
        expect(engine.isSyncing.value, isTrue);
        engine.setAvailable(false);
      };
      final cubit = SyncBannerCubit(engine: engine);

      final syncFuture = cubit.sync();
      expect(cubit.state, isA<SyncBannerSyncing>());

      await syncFuture;

      expect(engine.syncNowCallCount, 1);
      expect(cubit.state, isA<SyncBannerHidden>());
    },
  );

  test(
    'sync() just calls engine.syncNow() — synchronization is exclusively user-initiated through this',
    () async {
      final cubit = SyncBannerCubit(engine: engine);

      await cubit.sync();

      expect(engine.syncNowCallCount, 1);
    },
  );

  test(
    'ignores availability flips from the queue while a manual sync is in flight',
    () async {
      engine.setAvailable(true);
      engine.onSyncNow = () async {
        // A per-operation status flip mid-sync shouldn't flicker the banner —
        // `isSyncing` staying true throughout takes priority over these.
        engine.setAvailable(false);
        engine.setAvailable(true);
      };
      final cubit = SyncBannerCubit(engine: engine);

      await cubit.sync();

      // Only the post-sync re-read matters, not the mid-flight flips.
      expect(cubit.state, isA<SyncBannerAvailable>());
    },
  );

  test('dismiss() hides the banner without touching the engine', () {
    engine.setAvailable(true);
    final cubit = SyncBannerCubit(engine: engine);

    cubit.dismiss();

    expect(cubit.state, isA<SyncBannerHidden>());
    expect(engine.syncNowCallCount, 0);
  });
}
