import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/password_reset_verification.dart';
import 'package:beebase/domain/repositories/password_reset_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/forgot_password_otp_state.dart';
part 'state/forgot_password_otp_initial.dart';
part 'state/forgot_password_otp_loading.dart';
part 'state/forgot_password_otp_success.dart';
part 'state/forgot_password_otp_error.dart';
part 'mixin/forgot_password_otp_emitter.dart';

/// Step 2 of the forgot-password flow — verifies the OTP against the flow
/// started by `ForgotPasswordEmailCubit`. Its own attempt cap is separate
/// from the account's login lockout, and failures never distinguish an
/// ineligible flow from a real account's wrong code.
final class ForgotPasswordOtpCubit extends Cubit<ForgotPasswordOtpState> with ForgotPasswordOtpEmitter {
  ForgotPasswordOtpCubit({required this.repository}) : super(const ForgotPasswordOtpInitial());

  final IPasswordResetFlow repository;

  Future<void> verify({required String flowToken, required String otp}) {
    return emitVerify(repository, flowToken: flowToken, otp: otp);
  }
}
