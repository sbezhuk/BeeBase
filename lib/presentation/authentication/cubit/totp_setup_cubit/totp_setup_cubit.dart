import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/totp_setup_state.dart';
part 'state/totp_setup_initial.dart';
part 'state/totp_setup_loading.dart';
part 'state/totp_setup_success.dart';
part 'state/totp_setup_error.dart';
part 'mixin/totp_setup_emitter.dart';

/// Completes a pending TOTP setup challenge (issued by registration, or by
/// login when an account never finished 2FA setup) — the only way a pending
/// setup ever turns into a full session.
final class TotpSetupCubit extends Cubit<TotpSetupState> with TotpSetupEmitter {
  TotpSetupCubit({required this.repository, required this.authenticationCubit}) : super(const TotpSetupInitial());

  final AuthenticationRepository repository;
  final AuthenticationCubit authenticationCubit;

  Future<void> verify({required String setupToken, required String otp}) {
    return emitVerify(repository, authenticationCubit, setupToken: setupToken, otp: otp);
  }
}
