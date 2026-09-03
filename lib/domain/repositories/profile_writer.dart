import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/profile.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IProfileWriter {
  /// Updates the authenticated user's first/last name and, optionally,
  /// their avatar. Email is never editable — see BEEB-29.
  ///
  /// Avatar handling: [newAvatarLocalFilePath] is the local path of a
  /// freshly picked photo (uploaded through the Media Service before the
  /// profile is saved); [removeAvatar] clears the current avatar entirely.
  /// Leaving both unset keeps whatever avatar is already set — matching
  /// auth-service's own contract for `PUT /api/v1/profile`'s `avatar`
  /// field. Only one of the two should ever be set at once — a caller
  /// passing both is a bug, and [removeAvatar] wins.
  Future<Either<Failure, Profile>> updateProfile({
    required String firstName,
    required String lastName,
    String? newAvatarLocalFilePath,
    bool removeAvatar = false,
  });
}
