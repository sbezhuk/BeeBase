import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/repositories/password_reset_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/reset_password_state.dart';
part 'state/reset_password_initial.dart';
part 'state/reset_password_loading.dart';
part 'state/reset_password_success.dart';
part 'state/reset_password_error.dart';
part 'mixin/reset_password_emitter.dart';

/// Step 3 (final) of the forgot-password flow — completes it with a new
/// password. Never automatically authenticates: on success the user
/// returns to Login to sign in with their new password.
final class ResetPasswordCubit extends Cubit<ResetPasswordState> with ResetPasswordEmitter {
  ResetPasswordCubit({required this.repository}) : super(const ResetPasswordInitial());

  final IPasswordResetFlow repository;

  Future<void> confirm({required String resetToken, required String newPassword, required String confirmPassword}) {
    return emitConfirm(repository, resetToken: resetToken, newPassword: newPassword, confirmPassword: confirmPassword);
  }
}
