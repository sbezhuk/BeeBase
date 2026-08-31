import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

abstract interface class IMediaReader {
  Future<Either<Failure, Page<MediaAttachment>>> getMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required int page,
    required int limit,
  });

  /// Raw file bytes for [id], via the authenticated `.../download` endpoint —
  /// the only way `MediaThumbnail` may fetch a photo it doesn't already have
  /// a local copy of (see CLAUDE.md: the UI layer never calls a data source
  /// directly, always through a repository).
  Future<Either<Failure, List<int>>> downloadMedia(String id);
}
