import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IApiaryWriter {
  Future<Either<Failure, Apiary>> createApiary({
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  });

  Future<Either<Failure, Apiary>> updateApiary({
    required String id,
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  });

  Future<Either<Failure, void>> deleteApiary(String id);

  /// Links [mediaId] (already uploaded, but not yet attached to anything)
  /// to [apiaryId] - the only way to attach media now that media-service's
  /// own attach endpoint is internal-only. Used by `MediaRepositoryImpl`
  /// via `IOwnerImageWriter`, never called directly by UI code.
  Future<Either<Failure, void>> addApiaryImage({
    required String apiaryId,
    required String mediaId,
  });

  /// Removes [mediaId] from [apiaryId]'s own `images` - the reverse of
  /// [addApiaryImage]. Used by `MediaRepositoryImpl.removeMedia` via
  /// `IOwnerImageWriter` right before the underlying file is hard-deleted,
  /// so no stale reference is left behind to block a future
  /// [addApiaryImage] call for this apiary - apiary-service validates
  /// every id in `images` against media-service on every `PUT`, including
  /// ones this client isn't otherwise touching in that call.
  Future<Either<Failure, void>> removeApiaryImage({
    required String apiaryId,
    required String mediaId,
  });
}
