import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/data/models/extensions/media_extension.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/local/media_sync_status.dart';

/// Cross-references the cached (global, across every owner) media list
/// against the offline operation queue, so `MediaRepositoryImpl` can show a
/// not-yet-synced photo alongside the server's list, and tag every photo
/// with the right [MediaSyncStatus]. Mirrors `ApiaryCacheMerger` exactly.
final class MediaCacheMerger {
  const MediaCacheMerger();

  /// A fetch of [ids] (media-service's `GET /api/v1/media` has no pagination
  /// of its own anymore — every call is the complete answer, not a page): the
  /// fresh server response becomes the new front of the cache for just the
  /// rows whose id is in [ids] — every cached row for an id *outside* [ids]
  /// is passed through untouched. [mediaCacheKey] backs a single global cache
  /// shared by every Apiary/Hive; without scoping the replacement to just
  /// this request's ids, fetching one gallery would silently discard every
  /// other owner's already-synced, previously cached photos (they aren't in
  /// this response, and aren't "still pending" for this request either).
  ///
  /// Within that slice: the fresh response wins, except for any id with a
  /// not-yet-synced pending operation — that one comes from [oldCache]
  /// instead, so a not-yet-synced photo's placeholder isn't shadowed or
  /// duplicated by a stale server copy of the same id.
  List<MediaResponse> mergeForIds(
    List<MediaResponse> serverItems,
    List<MediaResponse> oldCache, {
    required Set<String> ids,
    required List<OfflineOperation> pendingOps,
  }) {
    final unsyncedLocalIds = pendingOps
        .where(
          (operation) =>
              operation.status != OperationStatus.synced &&
              operation.localEntityId != null,
        )
        .map((operation) => operation.localEntityId)
        .toSet();
    final oldById = {for (final response in oldCache) response.id: response};
    final serverFiltered = serverItems
        .where((response) => !unsyncedLocalIds.contains(response.id))
        .map((response) => _withKnownLocalPath(response, oldById[response.id]));
    final stillPending = ids
        .where(unsyncedLocalIds.contains)
        .map((id) => oldById[id])
        .whereType<MediaResponse>();
    final untouched = oldCache.where((response) => !ids.contains(response.id));
    return [...untouched, ...serverFiltered, ...stillPending];
  }

  /// A fresh server record never carries a [MediaResponse.localFilePath] —
  /// the server has no concept of it. Without this, a photo that was
  /// downloaded-and-cached once would forget it has a local copy on every
  /// subsequent refresh (pull-to-refresh, an owner-list-changed reload, …),
  /// forcing a redundant re-download every time. [old] is the same id's
  /// previous cache entry, if any.
  MediaResponse _withKnownLocalPath(MediaResponse fresh, MediaResponse? old) {
    if (old?.localFilePath == null) {
      return fresh;
    }
    return fresh.copyWith(localFilePath: old!.localFilePath);
  }

  List<MediaAttachment> toEntities(
    List<MediaResponse> responses,
    List<OfflineOperation> pendingOps,
  ) {
    return responses
        .map(
          (response) => response.toEntity().copyWith(
            syncStatus: _statusFor(response.id, pendingOps),
          ),
        )
        .toList();
  }

  MediaSyncStatus _statusFor(String id, List<OfflineOperation> pendingOps) {
    final matches = pendingOps.where(
      (operation) => operation.localEntityId == id,
    );
    if (matches.isEmpty) {
      return MediaSyncStatus.synced;
    }
    return switch (matches.last.status) {
      OperationStatus.pending ||
      OperationStatus.inProgress => MediaSyncStatus.pending,
      OperationStatus.failed => MediaSyncStatus.failed,
      OperationStatus.synced => MediaSyncStatus.synced,
    };
  }
}
