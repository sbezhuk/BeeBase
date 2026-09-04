import 'package:beebase/data/models/media_response.dart';

abstract interface class IMediaDataSource {
  /// Only the caller's own media among [ids] comes back, in request order,
  /// with unknown/foreign/duplicate ids silently omitted/collapsed — never
  /// paginated (see media-service's `GET /api/v1/media`), so this always
  /// returns the complete answer in one call.
  Future<List<MediaResponse>> listMedia({required List<String> ids});

  /// Uploads a file on its own, owned only by the caller — no apiary or hive
  /// needs to exist yet, and this never attaches it to one.
  /// media-service's own attach endpoint is
  /// internal-only (blocked at beebase-gateway) - linking this id to an
  /// owner happens via `IApiaryDataSource.updateApiary`/
  /// `IHiveDataSource.updateHive`'s `images` field instead (see
  /// `ApiaryRepositoryImpl.addApiaryImage`/`HiveRepositoryImpl.addHiveImage`).
  ///
  /// Returns the stored file's full metadata rather than just its id — most
  /// importantly [MediaResponse.imageUrl], the authenticated URL the photo
  /// is rendered from from this moment on (see `CachedMediaImage`).
  Future<MediaResponse> uploadMedia({
    required String filePath,
    required String originalFilename,
    required String contentType,
    void Function(int sent, int total)? onSendProgress,
  });

  Future<void> deleteMedia(String id);
}
