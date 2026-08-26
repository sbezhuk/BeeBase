import 'dart:async';

import 'package:beebase/core/services/session_service.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/authentication_state.dart';
part 'state/authentication_unknown.dart';
part 'state/authentication_authenticated.dart';
part 'state/authentication_unauthenticated.dart';
part 'mixin/authentication_emitter.dart';

/// Global authentication gate state — shared app-wide (registered as a
/// singleton, unlike per-screen cubits) since the router guard, the root
/// widget, and any authenticated screen all need to observe and react to the
/// same session.
class AuthenticationCubit extends Cubit<AuthenticationState>
    with AuthenticationEmitter {
  AuthenticationCubit({
    required this.repository,
    required SessionService sessionService,
  }) : super(const AuthenticationUnknown()) {
    _sessionExpiredSubscription = sessionService.onSessionExpired.listen(
      (_) => emit(const AuthenticationUnauthenticated()),
    );
  }

  final AuthenticationRepository repository;
  late final StreamSubscription<void> _sessionExpiredSubscription;

  Future<void> restoreSession() => emitRestoreSession(repository);

  void setAuthenticated(User user) => emit(AuthenticationAuthenticated(user));

  Future<void> logout() => emitLogout(repository);

  @override
  Future<void> close() {
    unawaited(_sessionExpiredSubscription.cancel());
    return super.close();
  }
}
