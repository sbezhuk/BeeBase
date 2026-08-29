import 'dart:async';

import 'package:beebase/core/offline/sync_engine.dart';
import 'package:beebase/presentation/sync/cubit/sync_banner_cubit/sync_banner_cubit.dart';
import 'package:beebase/presentation/sync/offline_sync_banner.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSyncEngine implements SyncEngine {
  final ValueNotifier<bool> _available = ValueNotifier(false);
  int syncNowCallCount = 0;
  Completer<void>? syncGate;

  @override
  ValueListenable<bool> get syncAvailable => _available;

  @override
  void start() {}

  @override
  Future<void> refreshAvailability() async {}

  @override
  Future<void> syncNow() async {
    syncNowCallCount++;
    await syncGate?.future;
  }

  void setAvailable(bool value) => _available.value = value;
}

void main() {
  late _FakeSyncEngine engine;
  late SyncBannerCubit cubit;

  setUp(() {
    engine = _FakeSyncEngine();
    cubit = SyncBannerCubit(engine: engine);
  });

  tearDown(() => cubit.close());

  Future<void> pumpBanner(WidgetTester tester, {double topInset = 0}) {
    return tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(top: topInset)),
        child: MaterialApp(
          home: Scaffold(
            body: BlocProvider<SyncBannerCubit>.value(value: cubit, child: const OfflineSyncBanner()),
          ),
        ),
      ),
    );
  }

  // easy_localization has no EasyLocalization ancestor in this test, so
  // `.tr()` falls back to returning the key itself — the widget under test
  // is unaffected either way, only the matched string differs from prod.
  const actionKey = 'sync.banner.action';

  testWidgets('clears the top system inset instead of rendering under it', (tester) async {
    const topInset = 44.0;
    engine.setAvailable(true);
    await pumpBanner(tester, topInset: topInset);

    final cardTop = tester.getTopLeft(find.byType(AppSnackBarCard)).dy;

    expect(cardTop, greaterThanOrEqualTo(topInset));
  });

  testWidgets('renders nothing when there is nothing to sync', (tester) async {
    await pumpBanner(tester);

    expect(find.text(actionKey), findsNothing);
  });

  testWidgets('tapping the sync action invokes the sync engine', (tester) async {
    engine.setAvailable(true);
    await pumpBanner(tester);

    await tester.tap(find.text(actionKey));
    await tester.pump();

    expect(engine.syncNowCallCount, 1);
  });

  testWidgets('shows a progress indicator and no action while syncing', (tester) async {
    engine
      ..setAvailable(true)
      ..syncGate = Completer<void>();
    await pumpBanner(tester);

    await tester.tap(find.text(actionKey));
    await tester.pump();

    expect(find.text(actionKey), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    engine.syncGate!.complete();
    await tester.pump();
  });
}
