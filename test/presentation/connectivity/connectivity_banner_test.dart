import 'dart:async';

import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/presentation/connectivity/connectivity_banner.dart';
import 'package:beebase/presentation/connectivity/cubit/connectivity_cubit/connectivity_cubit.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectivityService implements IConnectivityService {
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get status => _controller.stream;

  void emit(bool online) => _controller.add(online);

  Future<void> dispose() => _controller.close();
}

void main() {
  late _FakeConnectivityService connectivity;
  late ConnectivityCubit cubit;

  setUp(() {
    connectivity = _FakeConnectivityService();
    cubit = ConnectivityCubit(connectivity: connectivity);
  });

  tearDown(() async {
    await cubit.close();
    await connectivity.dispose();
  });

  // Mirrors OfflineSyncBanner's own test: the banner presents through the
  // shared AppSnackBar overlay from a post-frame callback, so every helper
  // flushes that frame before handing control back to the test body.
  Future<void> pumpBanner(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<ConnectivityCubit>.value(value: cubit, child: const ConnectivityBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders nothing while online', (tester) async {
    await pumpBanner(tester);

    expect(find.byType(AppSnackBarCard), findsNothing);
  });

  testWidgets('shows a persistent banner when connectivity drops', (tester) async {
    await pumpBanner(tester);

    connectivity.emit(false);
    await tester.pumpAndSettle();

    expect(find.byType(AppSnackBarCard), findsOneWidget);
  });

  // easy_localization has no EasyLocalization ancestor in this test, so
  // `.tr()` falls back to returning the key itself.
  const backOnlineKey = 'sync.banner.backOnline';

  testWidgets('swaps the persistent offline banner for a "back online" confirmation once connectivity returns', (tester) async {
    await pumpBanner(tester);
    connectivity.emit(false);
    await tester.pumpAndSettle();
    expect(find.byType(AppSnackBarCard), findsOneWidget);

    connectivity.emit(true);
    await tester.pumpAndSettle();

    expect(find.byType(AppSnackBarCard), findsOneWidget);
    expect(find.text(backOnlineKey), findsOneWidget);
  });

  testWidgets('does not show a "back online" confirmation on first mount while already online', (tester) async {
    await pumpBanner(tester);

    expect(find.text(backOnlineKey), findsNothing);
  });
}
