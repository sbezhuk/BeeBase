import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/data/models/extensions/hive_extension.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/local/hive_sync_status.dart';

/// Cross-references the cached Hive list against the offline operation
/// queue, so `HiveRepositoryImpl` can show a not-yet-synced hive alongside
/// the server's list, and tag every entity with the right [HiveSyncStatus].
///
/// The cache holds the caller's hives across every apiary — `GET
/// /api/v1/hives` has no apiary filter of its own — so, unlike
/// `ApiaryCacheMerger`'s single global list, this merger's output still
/// needs filtering down to one apiary by the repository after merging.
final class HiveCacheMerger {
  const HiveCacheMerger();

  /// Page 1 (initial load or refresh): the fresh server page becomes the new
  /// front of the cache, except for any id with a not-yet-synced pending
  /// operation — those come from [oldCache] instead, so a locally-edited (or
  /// still offline-created) hive's latest state isn't shadowed or
  /// duplicated by a stale server copy of the same id.
  List<HiveResponse> mergeFirstPage(
    List<HiveResponse> serverPage,
    List<HiveResponse> oldCache,
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
        .whereType<HiveResponse>();
    return [...serverFiltered, ...stillPending];
  }

  /// Page 2+: appends a fresh page onto whatever's already accumulated.
  /// Pending placeholders are never re-added here — they're already in
  /// [oldCache] from the page-1 fetch. Dedupes by id defensively: page-offset
  /// pagination over a collection that can change server-side between two
  /// page fetches can otherwise return the same row twice.
  List<HiveResponse> appendPage(
    List<HiveResponse> serverPage,
    List<HiveResponse> oldCache,
  ) {
    final existingIds = oldCache.map((response) => response.id).toSet();
    return [
      ...oldCache,
      ...serverPage.where((response) => !existingIds.contains(response.id)),
    ];
  }

  List<Hive> toEntities(
    List<HiveResponse> responses,
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

  HiveSyncStatus _statusFor(String id, List<OfflineOperation> pendingOps) {
    final matches = pendingOps.where(
      (operation) => operation.localEntityId == id,
    );
    if (matches.isEmpty) {
      return HiveSyncStatus.synced;
    }
    return switch (matches.last.status) {
      OperationStatus.pending ||
      OperationStatus.inProgress => HiveSyncStatus.pending,
      OperationStatus.failed => HiveSyncStatus.failed,
      OperationStatus.synced => HiveSyncStatus.synced,
    };
  }
}
