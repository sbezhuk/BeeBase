import 'dart:async';

import 'package:beebase/core/networking/network_info.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late MockConnectivity connectivity;

  setUp(() {
    connectivity = MockConnectivity();
  });

  group('NetworkInfo', () {
    test('isConnected returns false immediately when connectivity is none', () async {
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      final networkInfo = NetworkInfo(connectivity: connectivity);
      final connected = await networkInfo.isConnected;

      expect(connected, isFalse);
      networkInfo.dispose();
    });

    test('isConnected returns false when interface exists but host is unreachable', () async {
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      final networkInfo = NetworkInfo(
        connectivity: connectivity,
        lookupHost: 'invalid.unreachable.host.nonexistent',
      );
      final connected = await networkInfo.isConnected;

      expect(connected, isFalse);
      networkInfo.dispose();
    });

    test('isConnected returns true when interface exists and host is reachable', () async {
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      final networkInfo = NetworkInfo(
        connectivity: connectivity,
        lookupHost: 'google.com',
      );
      final connected = await networkInfo.isConnected;

      expect(connected, isTrue);
      networkInfo.dispose();
    });

    test('onConnectivityChanged stream emits when connectivity state changes', () async {
      final connectivityController =
          StreamController<List<ConnectivityResult>>.broadcast();
      when(() => connectivity.onConnectivityChanged)
          .thenAnswer((_) => connectivityController.stream);
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      final networkInfo = NetworkInfo(connectivity: connectivity);
      networkInfo.startMonitoring();

      final events = <bool>[];
      final sub = networkInfo.onConnectivityChanged.listen(events.add);

      // Simulate interface loss
      connectivityController.add([ConnectivityResult.none]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, contains(false));

      await sub.cancel();
      await connectivityController.close();
      networkInfo.dispose();
    });
  });
}
