import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/repositories/password_changer.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/change_password_state.dart';
part 'state/change_password_initial.dart';
part 'state/change_password_loading.dart';
part 'state/change_password_success.dart';
part 'state/change_password_error.dart';
part 'mixin/change_password_emitter.dart';

/// Changing a password is a credential-security event: the server revokes
/// every refresh token for the account on success, so this cubit logs the
/// app out locally right after — the caller's own session should
/// re-authenticate, matching the server-side revocation.
final class ChangePasswordCubit extends Cubit<ChangePasswordState> with ChangePasswordEmitter {
  ChangePasswordCubit({required this.repository, required this.authenticationCubit})
    : super(const ChangePasswordInitial());

  final IPasswordChanger repository;
  final AuthenticationCubit authenticationCubit;

  Future<void> submit({required String currentPassword, required String newPassword, required String otp}) {
    return emitSubmit(repository, authenticationCubit, currentPassword: currentPassword, newPassword: newPassword, otp: otp);
  }
}
