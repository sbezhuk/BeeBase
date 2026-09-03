import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IProfileReader {
  /// `GET /api/v1/profile` — the authenticated user's own profile. Falls
  /// back to the last cached copy when offline (see `ProfileRepositoryImpl`).
  Future<Either<Failure, User>> getProfile();
}
