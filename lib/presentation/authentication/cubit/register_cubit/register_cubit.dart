import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/register_state.dart';
part 'state/register_initial.dart';
part 'state/register_loading.dart';
part 'state/register_success.dart';
part 'state/register_error.dart';
part 'mixin/register_emitter.dart';

final class RegisterCubit extends Cubit<RegisterState> with RegisterEmitter {
  RegisterCubit({required this.repository, required this.authenticationCubit}) : super(const RegisterInitial());

  final AuthenticationRepository repository;
  final AuthenticationCubit authenticationCubit;

  Future<void> register({required String email, required String password}) {
    return emitRegister(repository, authenticationCubit, email: email, password: password);
  }
}
