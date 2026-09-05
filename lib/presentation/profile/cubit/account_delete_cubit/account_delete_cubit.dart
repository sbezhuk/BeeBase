import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/repositories/account_deleter.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/account_delete_state.dart';
part 'state/account_delete_initial.dart';
part 'state/account_delete_loading.dart';
part 'state/account_delete_success.dart';
part 'state/account_delete_error.dart';
part 'mixin/account_delete_emitter.dart';

/// Owns [ProfilePage]'s delete-account action.
final class AccountDeleteCubit extends Cubit<AccountDeleteState>
    with AccountDeleteEmitter {
  AccountDeleteCubit({required this.deleter, required this.authenticationCubit})
    : super(const AccountDeleteInitial());

  final IAccountDeleter deleter;
  final AuthenticationCubit authenticationCubit;

  Future<void> delete({required String otp}) =>
      emitDelete(deleter, authenticationCubit, otp: otp);
}
