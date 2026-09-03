import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/profile_writer.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/profile_edit_state.dart';
part 'state/profile_edit_initial.dart';
part 'state/profile_edit_loading.dart';
part 'state/profile_edit_success.dart';
part 'state/profile_edit_error.dart';
part 'mixin/profile_edit_emitter.dart';

final class ProfileEditCubit extends Cubit<ProfileEditState>
    with ProfileEditEmitter {
  ProfileEditCubit({required this.writer, required this.authenticationCubit})
    : super(const ProfileEditInitial());

  final IProfileWriter writer;
  final AuthenticationCubit authenticationCubit;

  Future<void> submit({
    required String firstName,
    required String lastName,
    String? newAvatarLocalFilePath,
    bool removeAvatar = false,
  }) => emitSubmit(
    writer,
    authenticationCubit,
    firstName: firstName,
    lastName: lastName,
    newAvatarLocalFilePath: newAvatarLocalFilePath,
    removeAvatar: removeAvatar,
  );
}
