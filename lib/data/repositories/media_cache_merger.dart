import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/data/models/extensions/media_extension.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/media_sync_status.dart';

/// Cross-references the cached (global, across every owner) media list
/// against the offline operation queue, so `MediaRepositoryImpl` can show a
/// not-yet-synced photo alongside the server's list, and tag every photo
/// with the right [MediaSyncStatus]. Mirrors `ApiaryCacheMerger` exactly.
final class MediaCacheMerger {
  const MediaCacheMerger();

  /// Page 1 (initial load or refresh) for one `(ownerType, ownerId)`: the
  /// fresh server page becomes the new front of the cache for that owner,
  /// except for any id with a not-yet-synced pending operation — those come
  /// from [oldCache] instead, so a not-yet-synced photo's placeholder isn't
  /// shadowed or duplicated by a stale server copy of the same id.
  List<MediaResponse> mergeFirstPage(
    List<MediaResponse> serverPage,
    List<MediaResponse> oldCache,
    List<OfflineOperation> pendingOps,
  ) {
    final unsyncedLocalIds = pendingOps
        .where(
          (operation) =>
              operation.status != OperationStatus.synced &&
              operation.localEntityId != null,
        )
        .map((operation) => operation.localEntityId)
        .toSet();
    final oldById = {for (final response in oldCache) response.id: response};
    final serverFiltered = serverPage.where(
      (response) => !unsyncedLocalIds.contains(response.id),
    );
    final stillPending = unsyncedLocalIds
        .map((id) => oldById[id])
        .whereType<MediaResponse>();
    return [...serverFiltered, ...stillPending];
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
