import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/repositories/profile_reader.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/profile_state.dart';
part 'state/profile_initial.dart';
part 'state/profile_loaded.dart';
part 'state/profile_error.dart';
part 'mixin/profile_emitter.dart';

/// Loads the authenticated user's profile from `GET /api/v1/profile` when
/// the Profile screen opens, then hands the fresh result to
/// [AuthenticationCubit] via [AuthenticationCubit.setAuthenticated] — that
/// singleton, not this screen-scoped cubit, is what every other screen
/// already reads the current user from, so this only ever exists to
/// trigger and reflect that one fetch.
final class ProfileCubit extends Cubit<ProfileState> with ProfileEmitter {
  ProfileCubit({required this.reader, required this.authenticationCubit})
    : super(const ProfileInitial());

  final IProfileReader reader;
  final AuthenticationCubit authenticationCubit;

  Future<void> load() => emitLoad(reader, authenticationCubit);
}
