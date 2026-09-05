import 'package:beebase/presentation/router/current_route_context_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrentRouteContextObserver', () {
    testWidgets('captures the initial route context after the first frame', (tester) async {
      final observer = CurrentRouteContextObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('home')),
        ),
      );

      expect(observer.currentContext, isNotNull);
    });

    testWidgets('updates to the pushed route after navigating forward', (tester) async {
      final observer = CurrentRouteContextObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('detail')))),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      final contextBeforePush = observer.currentContext;

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('detail'), findsOneWidget);
      expect(observer.currentContext, isNotNull);
      expect(observer.currentContext, isNot(same(contextBeforePush)));
    });

    testWidgets("restores the previous route's context after a pop", (tester) async {
      final observer = CurrentRouteContextObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (innerContext) => Scaffold(
                      body: TextButton(onPressed: () => Navigator.of(innerContext).pop(), child: const Text('back')),
                    ),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      expect(find.text('go'), findsOneWidget);
      expect(observer.currentContext, isNotNull);
    });
  });
}
