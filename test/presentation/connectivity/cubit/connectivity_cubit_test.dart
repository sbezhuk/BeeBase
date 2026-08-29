import 'dart:async';

import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/presentation/connectivity/cubit/connectivity_cubit/connectivity_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectivityService implements IConnectivityService {
  _FakeConnectivityService({this.initiallyOnline = true});

  final bool initiallyOnline;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => initiallyOnline;

  @override
  Stream<bool> get status => _controller.stream;

  void emit(bool online) => _controller.add(online);

  Future<void> dispose() => _controller.close();
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeConnectivityService connectivity;

  tearDown(() => connectivity.dispose());

  test('starts online before the initial check resolves', () async {
    connectivity = _FakeConnectivityService();
    final cubit = ConnectivityCubit(connectivity: connectivity);

    expect(cubit.state, isA<ConnectivityOnline>());

    await cubit.close();
  });

  test('corrects to offline once the initial check resolves offline', () async {
    connectivity = _FakeConnectivityService(initiallyOnline: false);
    final cubit = ConnectivityCubit(connectivity: connectivity);

    await _flush();

    expect(cubit.state, isA<ConnectivityOffline>());
    await cubit.close();
  });

  test('mirrors the connectivity stream flipping offline then online', () async {
    connectivity = _FakeConnectivityService();
    final cubit = ConnectivityCubit(connectivity: connectivity);
    await _flush();

    connectivity.emit(false);
    await _flush();
    expect(cubit.state, isA<ConnectivityOffline>());

    connectivity.emit(true);
    await _flush();
    expect(cubit.state, isA<ConnectivityOnline>());

    await cubit.close();
  });

  test('close() cancels the connectivity subscription cleanly', () async {
    connectivity = _FakeConnectivityService();
    final cubit = ConnectivityCubit(connectivity: connectivity);
    await _flush();

    await expectLater(cubit.close(), completes);
  });
}
