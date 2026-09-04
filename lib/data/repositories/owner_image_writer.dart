import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/domain/repositories/owner_image_writer.dart';
import 'package:beebase/utils/either.dart';

final class OwnerImageWriter implements IOwnerImageWriter {
  OwnerImageWriter({required this.apiaryWriter, required this.hiveWriter});

  final IApiaryWriter apiaryWriter;
  final IHiveWriter hiveWriter;

  @override
  Future<Either<Failure, void>> addImage({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String mediaId,
  }) => switch (ownerType) {
    MediaOwnerType.apiary => apiaryWriter.addApiaryImage(
      apiaryId: ownerId,
      mediaId: mediaId,
    ),
    MediaOwnerType.hive => hiveWriter.addHiveImage(
      hiveId: ownerId,
      mediaId: mediaId,
    ),
  };

  @override
  Future<Either<Failure, void>> removeImage({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String mediaId,
  }) => switch (ownerType) {
    MediaOwnerType.apiary => apiaryWriter.removeApiaryImage(
      apiaryId: ownerId,
      mediaId: mediaId,
    ),
    MediaOwnerType.hive => hiveWriter.removeHiveImage(
      hiveId: ownerId,
      mediaId: mediaId,
    ),
  };
}
