import 'package:beebase/core/media/media_image_cache.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/extensions/media_extension.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/domain/repositories/owner_image_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';

final class MediaRepositoryImpl extends Repository
    implements IMediaReader, IMediaWriter {
  MediaRepositoryImpl({
    required this.dataSource,
    required this.imageCache,
    required this.ownerImageWriter,
  });

  final IMediaDataSource dataSource;

  /// Seeded straight from the picked file the moment its upload succeeds, so
  /// the switch from `Image.file` to `CachedNetworkImage` costs no extra
  /// download, and evicted when a photo is deleted.
  final IMediaImageCache imageCache;

  /// Where linking an uploaded id to an owner actually happens now that
  /// media-service's own attach endpoint is internal-only - see
  /// [attachMedia].
  final IOwnerImageWriter ownerImageWriter;

  /// media-service's `GET /api/v1/media` has no pagination of its own — the
  /// response is always the complete answer for [ids] — so this returns a
  /// plain list rather than a [Page], reordered to match [ids].
  @override
  Future<Either<Failure, List<MediaAttachment>>> getMedia({
    required List<String> ids,
  }) async {
    if (ids.isEmpty) {
      return const Right([]);
    }

    return on(() async {
      final items = await dataSource.listMedia(ids: ids);
      return _ordered(items, ids);
    });
  }

  /// Uploads the bytes (owner-less — media-service requires no apiary/hive
  /// to exist yet), then links the resulting id to the owner via
  /// [ownerImageWriter]: media-service has no attach endpoint a client can
  /// call directly anymore, so "attach" is now apiary-service's/
  /// hive-service's job (see [IOwnerImageWriter]).
  @override
  Future<Either<Failure, MediaAttachment>> attachMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String localFilePath,
    required String originalFilename,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final result = await on(() async {
      final uploaded = await dataSource.uploadMedia(
        filePath: localFilePath,
        originalFilename: originalFilename,
        contentType: contentType,
        onSendProgress: onProgress == null
            ? null
            : (sent, total) => onProgress(total <= 0 ? 0 : sent / total),
      );
      // From here on the photo has an `imageUrl` and `CachedMediaImage`
      // renders it from that — seeding the cache from the file that was
      // just sent makes that first render free instead of a round trip for
      // bytes this device already has.
      await _seedImageCache(uploaded, localFilePath);
      return uploaded;
    });

    return result.fold(Left.new, (uploaded) async {
      final addResult = await ownerImageWriter.addImage(
        ownerType: ownerType,
        ownerId: ownerId,
        mediaId: uploaded.id,
      );
      return addResult.fold(Left.new, (_) => Right(uploaded.toEntity()));
    });
  }

  /// Best-effort: a cache seed that fails costs one re-download later, never
  /// the photo itself, so it must not fail the upload it rides along with.
  Future<void> _seedImageCache(MediaResponse uploaded, String localFilePath) {
    final imageUrl = uploaded.imageUrl;
    if (imageUrl == null) {
      return Future.value();
    }
    return imageCache.seedFromFile(imageUrl: imageUrl, filePath: localFilePath);
  }

  /// Detaches [id] from its owner's `images` *before* hard-deleting the
  /// file, in that order deliberately: apiary-service/hive-service validate
  /// every id in `images` against media-service on every `PUT`, so a photo
  /// deleted first and detached second (or not at all) leaves the owner
  /// referencing a now-nonexistent id — which then rejects the *next*
  /// unrelated `addApiaryImage`/`addHiveImage` call for that same owner
  /// with `image_not_found`, silently blocking every future photo add to
  /// it. Detaching first means a failed detach simply fails the whole
  /// remove (surfaced to the user as a retryable error) rather than ever
  /// reaching that broken state. A 404 from the delete itself still means
  /// an already-completed delete — see [on]'s `ignoreStatusCode`.
  @override
  Future<Either<Failure, void>> removeMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String id,
  }) async {
    final detachResult = await ownerImageWriter.removeImage(
      ownerType: ownerType,
      ownerId: ownerId,
      mediaId: id,
    );

    return detachResult.fold(Left.new, (_) async {
      final imageUrl = await _imageUrlOf(id);
      final result = await on(
        () => dataSource.deleteMedia(id),
        ignoreStatusCode: 404,
        onIgnoredStatusCode: () {},
      );

      return result.fold((failure) async => Left(failure), (_) async {
        if (imageUrl != null) {
          await imageCache.evict(imageUrl);
        }
        return const Right(null);
      });
    });
  }

  /// The cached render's key for [id], so it can be evicted once the photo
  /// is gone server-side and a later id/URL reuse can never render the old
  /// bytes. Best-effort — a lookup that fails just leaves the entry to the
  /// cache's own staleness policy.
  Future<String?> _imageUrlOf(String id) async {
    final result = await on(() => dataSource.listMedia(ids: [id]));
    return result.fold(
      (_) => null,
      (items) => items.isEmpty ? null : items.first.imageUrl,
    );
  }

  /// [responses] reordered to match [ids] — media-service returns them in
  /// request order already, but unknown/foreign ids are silently omitted,
  /// so this also drops anything that didn't come back.
  List<MediaAttachment> _ordered(List<MediaResponse> responses, List<String> ids) {
    final byId = {for (final response in responses) response.id: response};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!.toEntity(),
    ];
  }
}
