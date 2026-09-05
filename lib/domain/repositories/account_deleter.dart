import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IAccountDeleter {
  /// `DELETE /api/v1/profile` — permanently deletes the authenticated
  /// user's account and everything it owns on the backend (apiaries,
  /// hives, inspections and their media), then wipes what this device
  /// holds locally for that account: the offline SQLite database (which
  /// also clears any still-unsynchronized local changes) and cached media.
  ///
  /// [otp] must be a currently valid TOTP code — the backend proves the
  /// caller really intends so destructive an operation before deleting
  /// anything, the same "prove it's really you" gate change-password
  /// uses. An invalid/expired code fails with a [Failure] and leaves the
  /// account (and this device's local data) completely untouched.
  ///
  /// Deliberately does not touch the session/token — see
  /// `AccountDeleteCubit`, which hands off to `AuthenticationCubit.logout()`
  /// only once this succeeds, so the local session is never cleared ahead
  /// of the backend confirming deletion.
  Future<Either<Failure, void>> deleteAccount({required String otp});
}
