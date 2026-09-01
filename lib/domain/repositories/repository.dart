import 'package:beebase/core/networking/exceptions/cancellation_exception.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/utils/either.dart';

/// Base class for repository implementations. [on] runs [action] and
/// translates the exceptions thrown by the networking layer into a
/// [Failure], so callers only ever see an [Either].
abstract class Repository {
  const Repository();

  /// Runs [action], translating a thrown [ServerException]/
  /// [CancellationException]/[InternalException] into the matching
  /// [Failure]. If [ignoreStatusCode] is given and the [ServerException]'s
  /// `statusCode` matches it, the exception is treated as success instead —
  /// e.g. a delete that 404s because the entity is already gone server-side
  /// — and [onIgnoredStatusCode] is called to produce the result value.
  Future<Either<Failure, T>> on<T>(
    Future<T> Function() action, {
    int? ignoreStatusCode,
    T Function()? onIgnoredStatusCode,
  }) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      if (ignoreStatusCode != null && e.statusCode == ignoreStatusCode && onIgnoredStatusCode != null) {
        return Right(onIgnoredStatusCode());
      }
      return Left(ServerFailure(code: e.code, message: e.message, fields: e.fields));
    } on CancellationException catch (e) {
      return Left(CancellationFailure(e.message));
    } on InternalException catch (e) {
      return Left(InternalFailure(e.message));
    }
  }
}
