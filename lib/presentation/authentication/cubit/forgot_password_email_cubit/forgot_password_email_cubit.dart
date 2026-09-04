import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/password_reset_flow.dart';
import 'package:beebase/domain/repositories/password_reset_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/forgot_password_email_state.dart';
part 'state/forgot_password_email_initial.dart';
part 'state/forgot_password_email_loading.dart';
part 'state/forgot_password_email_success.dart';
part 'state/forgot_password_email_error.dart';
part 'mixin/forgot_password_email_emitter.dart';

/// Step 1 of the forgot-password flow: `Email submitted → OTP verified →
/// Password reset`. Always succeeds with an identical response shape
/// whether or not the email belongs to an eligible account, so this never
/// distinguishes "not found" from "not eligible" — see the API contract.
final class ForgotPasswordEmailCubit extends Cubit<ForgotPasswordEmailState> with ForgotPasswordEmailEmitter {
  ForgotPasswordEmailCubit({required this.repository}) : super(const ForgotPasswordEmailInitial());

  final IPasswordResetFlow repository;

  Future<void> submit({required String email}) => emitSubmit(repository, email: email);
}
