import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/extensions/apiary_extension.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/apiary_sync_status.dart';

/// Cross-references the cached Apiary list against the offline operation
/// queue, so `ApiaryRepositoryImpl` can show a not-yet-synced apiary
/// alongside the server's list, and tag every entity with the right
/// [ApiarySyncStatus].
final class ApiaryCacheMerger {
  const ApiaryCacheMerger();

  /// Page 1 (initial load or refresh): the fresh server page becomes the new
  /// front of the cache, except for any id with a not-yet-synced pending
  /// operation — those come from [oldCache] instead, so a locally-edited (or
  /// still offline-created) apiary's latest state isn't shadowed or
  /// duplicated by a stale server copy of the same id. Safe from
  /// duplicating a since-synced entry: `ApiaryOperationHandler` removes the
  /// local placeholder from the cache before the operation is ever marked
  /// synced.
  List<ApiaryResponse> mergeFirstPage(
    List<ApiaryResponse> serverPage,
    List<ApiaryResponse> oldCache,
    List<OfflineOperation> pendingOps,
  ) {
    final unsyncedLocalIds = pendingOps
        .where((operation) => operation.status != OperationStatus.synced && operation.localEntityId != null)
        .map((operation) => operation.localEntityId)
        .toSet();
    final oldById = {for (final response in oldCache) response.id: response};
    final serverFiltered = serverPage.where((response) => !unsyncedLocalIds.contains(response.id));
    final stillPending = unsyncedLocalIds.map((id) => oldById[id]).whereType<ApiaryResponse>();
    return [...serverFiltered, ...stillPending];
  }

  /// Page 2+: appends a fresh page onto whatever's already accumulated.
  /// Pending placeholders are never re-added here — they're already in
  /// [oldCache] from the page-1 fetch. Dedupes by id defensively: page-offset
  /// pagination over a collection that can change server-side between two
  /// page fetches can otherwise return the same row twice.
  List<ApiaryResponse> appendPage(List<ApiaryResponse> serverPage, List<ApiaryResponse> oldCache) {
    final existingIds = oldCache.map((response) => response.id).toSet();
    return [...oldCache, ...serverPage.where((response) => !existingIds.contains(response.id))];
  }

  List<Apiary> toEntities(List<ApiaryResponse> responses, List<OfflineOperation> pendingOps) {
    return responses.map((response) => response.toEntity().copyWith(syncStatus: _statusFor(response.id, pendingOps))).toList();
  }

  ApiarySyncStatus _statusFor(String id, List<OfflineOperation> pendingOps) {
    final matches = pendingOps.where((operation) => operation.localEntityId == id);
    if (matches.isEmpty) {
      return ApiarySyncStatus.synced;
    }
    return switch (matches.last.status) {
      OperationStatus.pending || OperationStatus.inProgress => ApiarySyncStatus.pending,
      OperationStatus.failed => ApiarySyncStatus.failed,
      OperationStatus.synced => ApiarySyncStatus.synced,
    };
  }
}
