import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IHiveWriter {
  Future<Either<Failure, Hive>> createHive({
    required String apiaryId,
    required String name,
    String? notes,
  });

  Future<Either<Failure, Hive>> updateHive({
    required String id,
    required String name,
    String? notes,
  });

  Future<Either<Failure, void>> deleteHive(String id);

  /// Links [mediaId] (already uploaded, but not yet attached to anything)
  /// to [hiveId] - the only way to attach media now that media-service's
  /// own attach endpoint is internal-only. Used by `MediaRepositoryImpl`
  /// via `IOwnerImageWriter`, never called directly by UI code.
  Future<Either<Failure, void>> addHiveImage({
    required String hiveId,
    required String mediaId,
  });

  /// Removes [mediaId] from [hiveId]'s own `images` - the reverse of
  /// [addHiveImage]. Used by `MediaRepositoryImpl.removeMedia` via
  /// `IOwnerImageWriter` right before the underlying file is hard-deleted,
  /// so no stale reference is left behind to block a future [addHiveImage]
  /// call for this hive - hive-service validates every id in `images`
  /// against media-service on every `PUT`, including ones this client
  /// isn't otherwise touching in that call.
  Future<Either<Failure, void>> removeHiveImage({
    required String hiveId,
    required String mediaId,
  });
}
