import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IMediaReader {
  /// Only the caller's own media among [ids] comes back, in request order —
  /// media-service's `GET /api/v1/media` has no pagination of its own
  /// anymore (see `IMediaDataSource.listMedia`), so this always returns the
  /// complete answer in one call rather than a [Page].
  Future<Either<Failure, List<MediaAttachment>>> getMedia({
    required List<String> ids,
  });

  /// Raw file bytes for [id], via the authenticated `.../download` endpoint —
  /// the only way `MediaThumbnail` may fetch a photo it doesn't already have
  /// a local copy of (see CLAUDE.md: the UI layer never calls a data source
  /// directly, always through a repository).
  Future<Either<Failure, List<int>>> downloadMedia(String id);

  /// Records that [id] now has a valid local render-cache copy at
  /// [localFilePath], so a future `getMedia` call (a reload, a pull-to-
  /// refresh, a cold app restart) knows not to re-download it. Called once a
  /// `downloadMedia` result has actually been written to disk — see
  /// `MediaGalleryEmitter.resolveItemDisplayPath`. Best-effort and never
  /// throws, matching `LocalDataSource`.
  Future<void> cacheDownloadedMedia(String id, String localFilePath);
}
