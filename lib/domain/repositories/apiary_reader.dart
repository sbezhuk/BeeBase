import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

abstract interface class IApiaryReader {
  Future<Either<Failure, Page<Apiary>>> getApiaries({required int page, required int limit});

  Future<Either<Failure, Apiary>> getApiary(String id);

  /// Reads [id] straight from the local cache — no network round trip, and
  /// `null` if it isn't cached. Used to refresh an already-open details
  /// screen after a background sync reconciles that entity's cache entry
  /// (e.g. an address resolved from a placeholder once its offline
  /// create/update operation syncs), without re-fetching the whole list.
  Future<Apiary?> getCachedApiary(String id);
}
