import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IPasswordChanger {
  /// Requires both [currentPassword] and a valid [otp] — knowing the
  /// current password alone is never sufficient. On success, every refresh
  /// token belonging to the account is revoked server-side.
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String otp,
  });
}
