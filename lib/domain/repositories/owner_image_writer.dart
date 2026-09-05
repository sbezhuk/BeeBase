import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/utils/either.dart';

/// `MediaRepositoryImpl`'s one dependency on Apiary/Hive/Inspection: linking
/// an already-uploaded media id to whichever of the three owns it.
/// Media-service no longer exposes a client-facing attach endpoint (see
/// beebase-gateway's internal-only routing), so attaching now means asking
/// the owning service to add the id to its own `images` - this interface
/// just routes to [IApiaryWriter.addApiaryImage]/[IHiveWriter.addHiveImage]/
/// [IInspectionWriter.addInspectionImage] by [MediaOwnerType], keeping
/// `MediaRepositoryImpl` itself generic over which kind of owner it's
/// attaching to.
abstract interface class IOwnerImageWriter {
  Future<Either<Failure, void>> addImage({required MediaOwnerType ownerType, required String ownerId, required String mediaId});

  /// The reverse of [addImage] - routes to
  /// [IApiaryWriter.removeApiaryImage]/[IHiveWriter.removeHiveImage]/
  /// [IInspectionWriter.removeInspectionImage] by [ownerType].
  Future<Either<Failure, void>> removeImage({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String mediaId,
  });
}
