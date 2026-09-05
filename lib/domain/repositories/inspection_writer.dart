import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IInspectionWriter {
  Future<Either<Failure, Inspection>> createInspection({
    required String hiveId,
    required DateTime date,
    required InspectionType type,
    required String notes,
  });

  Future<Either<Failure, Inspection>> updateInspection({
    required String hiveId,
    required String id,
    required DateTime date,
    required InspectionType type,
    required String notes,
  });

  Future<Either<Failure, void>> deleteInspection({required String hiveId, required String id});

  /// Links [mediaId] (already uploaded, but not yet attached to anything)
  /// to [inspectionId] - the only way to attach media now that media-service's
  /// own attach endpoint is internal-only. Used by `MediaRepositoryImpl`
  /// via `IOwnerImageWriter`, never called directly by UI code.
  Future<Either<Failure, void>> addInspectionImage({required String inspectionId, required String mediaId});

  /// Removes [mediaId] from [inspectionId]'s own `images` - the reverse of
  /// [addInspectionImage]. Used by `MediaRepositoryImpl.removeMedia` via
  /// `IOwnerImageWriter` right before the underlying file is hard-deleted,
  /// so no stale reference is left behind to block a future
  /// [addInspectionImage] call for this inspection - inspection-service
  /// validates every id in `images` against media-service on every `PUT`,
  /// including ones this client isn't otherwise touching in that call.
  Future<Either<Failure, void>> removeInspectionImage({required String inspectionId, required String mediaId});
}
