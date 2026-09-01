import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';

/// The `entityType` [MediaOperationHandler] registers offline photo
/// operations under — mirrored here as a raw string (rather than importing
/// `MediaOperationHandler`, which lives in `data/media/` and pulls in
/// upload/data-source dependencies this merger-support code has no business
/// depending on) so [combinedOperationStatus] can recognize a queued photo
/// operation without a heavier import.
const mediaOperationEntityType = 'media';

/// The JSON key `MediaUploadRequest` serializes its owning Apiary/Hive id
/// under, inside a queued media `create` operation's payload — mirrored here
/// as a raw string rather than importing `MediaUploadRequest` itself, for the
/// same decoupling reason as [mediaOperationEntityType].
const _mediaPayloadOwnerIdKey = 'owner_id';

/// The synchronization status for [entityId] (an Apiary or Hive id), derived
/// from *all* offline operations relevant to it: its own create/update
/// operations, plus any offline photo (`media`) `create` operations queued
/// against it as owner. This is how a tile ends up showing "needs sync" when
/// the only still-unsynced local change is a photo attached to it, not an
/// edit to the entity itself — shared by `ApiaryCacheMerger` and
/// `HiveCacheMerger` so both derive it identically. `null` means nothing is
/// outstanding for this id at all (the caller should treat that as synced).
///
/// Matching a media operation by [_mediaPayloadOwnerIdKey] alone (without
/// also checking its `owner_type`) is safe: Apiary and Hive ids — whether
/// server-assigned or `LocalIdGenerator`-issued — are drawn from the same
/// globally-unique id space, so there's no realistic risk of a hive id
/// colliding with an apiary id.
OperationStatus? combinedOperationStatus({required String entityId, required List<OfflineOperation> operations}) {
  final relevant = operations.where(
    (operation) =>
        operation.localEntityId == entityId ||
        (operation.entityType == mediaOperationEntityType && operation.payload[_mediaPayloadOwnerIdKey] == entityId),
  );
  if (relevant.isEmpty) {
    return null;
  }
  if (relevant.any((operation) => operation.status == OperationStatus.failed)) {
    return OperationStatus.failed;
  }
  if (relevant.any(
    (operation) => operation.status == OperationStatus.pending || operation.status == OperationStatus.inProgress,
  )) {
    return OperationStatus.pending;
  }
  return OperationStatus.synced;
}
