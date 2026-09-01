import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/data/models/extensions/inspection_extension.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/local/inspection_sync_status.dart';

/// Cross-references the cached Inspection list against the offline
/// operation queue, so `InspectionRepositoryImpl` can show a not-yet-synced
/// inspection alongside the server's list, and tag every entity with the
/// right [InspectionSyncStatus]. Mirrors [HiveCacheMerger] exactly — the
/// cache holds the caller's inspections across every hive, so this merger's
/// output still needs filtering down to one hive by the repository after
/// merging.
final class InspectionCacheMerger {
  const InspectionCacheMerger();

  /// Page 1 (initial load or refresh): the fresh server page becomes the new
  /// front of the cache, except for any id with a not-yet-synced pending
  /// operation — those come from [oldCache] instead, so a locally-edited (or
  /// still offline-created) inspection's latest state isn't shadowed or
  /// duplicated by a stale server copy of the same id.
  List<InspectionResponse> mergeFirstPage(
    List<InspectionResponse> serverPage,
    List<InspectionResponse> oldCache,
    List<OfflineOperation> pendingOps,
  ) {
    final unsyncedLocalIds = pendingOps
        .where(
          (operation) =>
              operation.status != OperationStatus.synced && operation.localEntityId != null,
        )
        .map((operation) => operation.localEntityId)
        .toSet();
    final oldById = {for (final response in oldCache) response.id: response};
    final serverFiltered = serverPage.where((response) => !unsyncedLocalIds.contains(response.id));
    final stillPending = unsyncedLocalIds.map((id) => oldById[id]).whereType<InspectionResponse>();
    return [...serverFiltered, ...stillPending];
  }

  /// Page 2+: appends a fresh page onto whatever's already accumulated.
  /// Pending placeholders are never re-added here — they're already in
  /// [oldCache] from the page-1 fetch. Dedupes by id defensively: page-offset
  /// pagination over a collection that can change server-side between two
  /// page fetches can otherwise return the same row twice.
  List<InspectionResponse> appendPage(
    List<InspectionResponse> serverPage,
    List<InspectionResponse> oldCache,
  ) {
    final existingIds = oldCache.map((response) => response.id).toSet();
    return [...oldCache, ...serverPage.where((response) => !existingIds.contains(response.id))];
  }

  List<Inspection> toEntities(
    List<InspectionResponse> responses,
    List<OfflineOperation> pendingOps,
  ) {
    return responses
        .map(
          (response) =>
              response.toEntity().copyWith(syncStatus: _statusFor(response.id, pendingOps)),
        )
        .toList();
  }

  InspectionSyncStatus _statusFor(String id, List<OfflineOperation> pendingOps) {
    final matches = pendingOps.where((operation) => operation.localEntityId == id);
    if (matches.isEmpty) {
      return InspectionSyncStatus.synced;
    }
    return switch (matches.last.status) {
      OperationStatus.pending || OperationStatus.inProgress => InspectionSyncStatus.pending,
      OperationStatus.failed => InspectionSyncStatus.failed,
      OperationStatus.synced => InspectionSyncStatus.synced,
    };
  }
}
