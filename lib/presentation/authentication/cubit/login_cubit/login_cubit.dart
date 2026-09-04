import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/login_state.dart';
part 'state/login_initial.dart';
part 'state/login_loading.dart';
part 'state/login_success.dart';
part 'state/login_error.dart';
part 'mixin/login_emitter.dart';

final class LoginCubit extends Cubit<LoginState> with LoginEmitter {
  LoginCubit({required this.repository}) : super(const LoginInitial());

  final AuthenticationRepository repository;

  Future<void> login({required String email, required String password}) {
    return emitLogin(repository, email: email, password: password);
  }
}
