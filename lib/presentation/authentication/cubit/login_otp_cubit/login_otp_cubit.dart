import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/login_otp_state.dart';
part 'state/login_otp_initial.dart';
part 'state/login_otp_loading.dart';
part 'state/login_otp_success.dart';
part 'state/login_otp_error.dart';
part 'mixin/login_otp_emitter.dart';

/// Completes a login begun by `LoginCubit` once it already has 2FA enabled
/// (a `LoginOtpChallenge`) — the only way that challenge turns into a full
/// session.
final class LoginOtpCubit extends Cubit<LoginOtpState> with LoginOtpEmitter {
  LoginOtpCubit({required this.repository, required this.authenticationCubit}) : super(const LoginOtpInitial());

  final AuthenticationRepository repository;
  final AuthenticationCubit authenticationCubit;

  Future<void> verify({required String challengeToken, required String otp}) {
    return emitVerify(repository, authenticationCubit, challengeToken: challengeToken, otp: otp);
  }
}
