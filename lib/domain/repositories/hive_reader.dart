import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

abstract interface class IHiveReader {
  /// [apiaryId] scopes the result client-side — `GET /api/v1/hives` has no
  /// apiary filter of its own (it returns a page of *all* of the caller's
  /// hives), so [HiveRepositoryImpl] fetches the global page and filters it
  /// down before returning.
  Future<Either<Failure, Page<Hive>>> getHives({
    required String apiaryId,
    required int page,
    required int limit,
  });

  Future<Either<Failure, Hive>> getHive(String id);
}
