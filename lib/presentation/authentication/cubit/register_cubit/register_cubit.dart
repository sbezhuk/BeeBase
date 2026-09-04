import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/register_state.dart';
part 'state/register_initial.dart';
part 'state/register_loading.dart';
part 'state/register_success.dart';
part 'state/register_error.dart';
part 'mixin/register_emitter.dart';

final class RegisterCubit extends Cubit<RegisterState> with RegisterEmitter {
  RegisterCubit({required this.repository}) : super(const RegisterInitial());

  final AuthenticationRepository repository;

  Future<void> register({required String email, required String password}) {
    return emitRegister(repository, email: email, password: password);
  }
}
