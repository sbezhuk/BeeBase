import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/profile.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IProfileReader {
  /// `GET /api/v1/profile` — the authenticated user's own profile.
  Future<Either<Failure, Profile>> getProfile();
}
