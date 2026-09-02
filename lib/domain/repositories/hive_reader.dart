import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

abstract interface class IHiveReader {
  /// [apiaryId] scopes the result client-side — `GET /api/v1/hives` has no
  /// apiary filter of its own (it returns a page of *all* of the caller's
  /// hives), so [HiveRepositoryImpl] fetches the global page and filters it
  /// down before returning.
  Future<Either<Failure, Page<Hive>>> getHives({required String apiaryId, required int page, required int limit});

  Future<Either<Failure, Hive>> getHive(String id);

  /// Total hive count per apiary id, across every hive the caller owns.
  /// `GET /api/v1/hives` has no count of its own and no apiary filter (see
  /// [getHives]), so an accurate total means walking every page once; used
  /// by the apiary list to show each apiary's real hive count instead of a
  /// placeholder.
  Future<Either<Failure, Map<String, int>>> getHiveCounts();

  /// Reads [id] straight from the local cache — no network round trip, and
  /// `null` if it isn't cached. Mirrors `IApiaryReader.getCachedApiary`; used
  /// by `MediaGalleryCubit` (via DI's `resolveImages` wiring) to source a
  /// hive gallery's current `images` id list without a server round trip on
  /// every reload.
  Future<Hive?> getCachedHive(String id);
}
