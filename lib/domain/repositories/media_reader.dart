import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IMediaReader {
  /// Only the caller's own media among [ids] comes back, in request order —
  /// media-service's `GET /api/v1/media` has no pagination of its own
  /// (see `IMediaDataSource.listMedia`), so this always returns the
  /// complete answer in one call rather than a [Page].
  ///
  /// Each result carries the `imageUrl` its photo is rendered from (see
  /// `CachedMediaImage`); nothing here ever fetches image bytes itself —
  /// that is `MediaImageCacheManager`'s job, behind `CachedNetworkImage`.
  Future<Either<Failure, List<MediaAttachment>>> getMedia({
    required List<String> ids,
  });
}
