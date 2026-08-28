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

  /// Keeps any cache entry still awaiting sync alongside the fresh server
  /// list, so a not-yet-synced offline-created apiary doesn't disappear the
  /// moment the next online fetch runs. Safe from duplicating a
  /// since-synced entry: `ApiaryOperationHandler` removes the local
  /// placeholder from the cache before the operation is ever marked synced.
  List<ApiaryResponse> mergeWithPending(
    List<ApiaryResponse> serverList,
    List<ApiaryResponse> oldCache,
    List<OfflineOperation> pendingOps,
  ) {
    final unsyncedLocalIds = pendingOps
        .where((operation) => operation.status != OperationStatus.synced && operation.localEntityId != null)
        .map((operation) => operation.localEntityId)
        .toSet();
    final stillPending = oldCache.where((response) => unsyncedLocalIds.contains(response.id));
    return [...serverList, ...stillPending];
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
