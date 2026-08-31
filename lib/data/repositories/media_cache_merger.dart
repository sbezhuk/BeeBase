import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/data/models/extensions/media_extension.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/domain/enum/media_sync_status.dart';

/// Cross-references the cached (global, across every owner) media list
/// against the offline operation queue, so `MediaRepositoryImpl` can show a
/// not-yet-synced photo alongside the server's list, and tag every photo
/// with the right [MediaSyncStatus]. Mirrors `ApiaryCacheMerger` exactly.
final class MediaCacheMerger {
  const MediaCacheMerger();

  /// Page 1 (initial load or refresh) for one `(ownerType, ownerIds)`: the
  /// fresh server page becomes the new front of the cache for that owner's
  /// slice only — every response belonging to a *different* owner is passed
  /// through untouched. [mediaCacheKey] backs a single global cache shared
  /// by every Apiary/Hive; without scoping the replacement to just this
  /// owner's rows, fetching one owner's gallery would silently discard every
  /// other owner's already-synced, previously cached photos (they aren't in
  /// this owner's server page, and aren't "still pending" for this owner
  /// either).
  ///
  /// [ownerIds] is usually just the one id the caller asked about, but
  /// carries two when that owner's own local id has resolved to a real
  /// server id since the last read: a not-yet-synced photo attached before
  /// that resolution is still filed under the old local id in [oldCache]
  /// (its own `create` operation hasn't run yet to rewrite it), so both ids
  /// have to be treated as "this owner" for it to survive the merge instead
  /// of looking like it belongs to nobody.
  ///
  /// Within that slice: the fresh server page wins, except for any id with a
  /// not-yet-synced pending operation — that one comes from [oldCache]
  /// instead, so a not-yet-synced photo's placeholder isn't shadowed or
  /// duplicated by a stale server copy of the same id.
  List<MediaResponse> mergeFirstPage(
    List<MediaResponse> serverPage,
    List<MediaResponse> oldCache, {
    required MediaOwnerType ownerType,
    required Set<String> ownerIds,
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
    final serverFiltered = serverPage
        .where((response) => !unsyncedLocalIds.contains(response.id))
        .map((response) => _withKnownLocalPath(response, oldById[response.id]));
    final stillPending = unsyncedLocalIds
        .map((id) => oldById[id])
        .whereType<MediaResponse>()
        .where(
          (response) =>
              response.ownerType == ownerType &&
              ownerIds.contains(response.ownerId),
        );
    final untouched = oldCache.where(
      (response) =>
          !(response.ownerType == ownerType &&
              ownerIds.contains(response.ownerId)),
    );
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

  /// Page 2+: appends a fresh page onto whatever's already accumulated,
  /// deduping defensively by id.
  List<MediaResponse> appendPage(
    List<MediaResponse> serverPage,
    List<MediaResponse> oldCache,
  ) {
    final existingIds = oldCache.map((response) => response.id).toSet();
    return [
      ...oldCache,
      ...serverPage.where((response) => !existingIds.contains(response.id)),
    ];
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
