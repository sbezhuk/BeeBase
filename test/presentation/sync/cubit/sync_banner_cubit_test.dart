import 'package:beebase/core/offline/sync_engine.dart';
import 'package:beebase/presentation/sync/cubit/sync_banner_cubit/sync_banner_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSyncEngine implements SyncEngine {
  final ValueNotifier<bool> _available = ValueNotifier(false);
  final ValueNotifier<bool> _pending = ValueNotifier(false);
  int syncNowCallCount = 0;
  Future<void> Function()? onSyncNow;

  @override
  ValueListenable<bool> get syncAvailable => _available;

  @override
  ValueListenable<bool> get hasPendingOperations => _pending;

  @override
  void start() {}

  @override
  Future<void> refreshAvailability() async {}

  @override
  Future<void> syncNow() async {
    syncNowCallCount++;
    final callback = onSyncNow;
    if (callback != null) {
      await callback();
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

  test('sync() emits Syncing, calls the engine, then reflects the final availability', () async {
    engine.setAvailable(true);
    engine.onSyncNow = () async => engine.setAvailable(false);
    final cubit = SyncBannerCubit(engine: engine);

    final syncFuture = cubit.sync();
    expect(cubit.state, isA<SyncBannerSyncing>());

    await syncFuture;

    expect(engine.syncNowCallCount, 1);
    expect(cubit.state, isA<SyncBannerHidden>());
  });

  test('ignores availability flips from the queue while a manual sync is in flight', () async {
    engine.setAvailable(true);
    engine.onSyncNow = () async {
      // A per-operation status flip mid-sync shouldn't flicker the banner.
      engine.setAvailable(false);
      engine.setAvailable(true);
    };
    final cubit = SyncBannerCubit(engine: engine);

    await cubit.sync();

    // Only the post-sync re-read matters, not the mid-flight flips.
    expect(cubit.state, isA<SyncBannerAvailable>());
  });

  test('dismiss() hides the banner without touching the engine', () {
    engine.setAvailable(true);
    final cubit = SyncBannerCubit(engine: engine);

    cubit.dismiss();

    expect(cubit.state, isA<SyncBannerHidden>());
    expect(engine.syncNowCallCount, 0);
  });
}
