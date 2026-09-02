import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';

/// The `entityType` [MediaOperationHandler] registers offline photo
/// operations under — mirrored here as a raw string (rather than importing
/// `MediaOperationHandler`, which lives in `data/media/` and pulls in
/// upload/data-source dependencies this merger-support code has no business
/// depending on) so [combinedOperationStatus] can recognize a queued photo
/// operation without a heavier import.
const mediaOperationEntityType = 'media';

/// The synchronization status for [entityId] (an Apiary or Hive id), derived
/// from *all* offline operations relevant to it: its own create/update
/// operations, plus any `imageAdd` operation queued against it (entityType
/// `apiary`/`hive`, `localEntityId` the apiary/hive's own id - see
/// `ApiaryRepositoryImpl`/`HiveRepositoryImpl._queueImageAdd`). This is how
/// a tile ends up showing "needs sync" when the only still-unsynced local
/// change is a photo added to it, not an edit to the entity itself - shared
/// by `ApiaryCacheMerger` and `HiveCacheMerger` so both derive it
/// identically. `null` means nothing is outstanding for this id at all (the
/// caller should treat that as synced).
///
/// A queued photo *delete* is deliberately not matched here (its
/// `entityType` is `media`, its `localEntityId` the media id, not the
/// owner's) - media-service's response carries no owner id to key it by,
/// so the owning tile simply won't show "pending sync" for the brief
/// window a queued delete is in flight. A queued photo *upload* isn't
/// matched either: it's owner-less by design (see `MediaUploadRequest`),
/// linking it to an owner is the separate `imageAdd` step this function
/// already catches.
OperationStatus? combinedOperationStatus({
  required String entityId,
  required List<OfflineOperation> operations,
}) {
  final relevant = operations.where(
    (operation) => operation.localEntityId == entityId,
  );
  if (relevant.isEmpty) {
    return null;
  }
  if (relevant.any((operation) => operation.status == OperationStatus.failed)) {
    return OperationStatus.failed;
  }
  if (relevant.any(
    (operation) =>
        operation.status == OperationStatus.pending ||
        operation.status == OperationStatus.inProgress,
  )) {
    return OperationStatus.pending;
  }
  return OperationStatus.synced;
}
