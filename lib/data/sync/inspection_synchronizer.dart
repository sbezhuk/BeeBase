import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';

final class InspectionSyncResult {
  const InspectionSyncResult({
    required this.totalPending,
    required this.syncedCount,
    required this.failedCount,
    this.skippedCount = 0,
    this.errors = const [],
  });

  final int totalPending;
  final int syncedCount;
  final int failedCount;

  /// Inspections left pending because their parent hive still requires
  /// synchronization (or failed this round) — not a failure, just not yet
  /// eligible. Retried on the next sync pass.
  final int skippedCount;
  final List<String> errors;

  bool get isSuccess => failedCount == 0 && errors.isEmpty;
}

abstract interface class IInspectionSynchronizer {
  Future<InspectionSyncResult> syncInspections();
}

/// Synchronizes offline inspection changes with inspection-service, honoring
/// the strict `Hive -> Inspection` dependency: an inspection whose parent
/// hive hasn't synchronized yet (still tracked by [Inspection.hiveLocalId])
/// is left pending rather than sent to the backend — see [_resolveParent].
/// Callers must run [IHiveSynchronizer].syncHives() first on each sync pass
/// (see `DataSynchronizer`, the single entry point that guarantees this
/// ordering, itself run after apiary sync) so that a parent hive which just
/// synced is picked up in the same pass instead of requiring a second manual
/// sync. Inspection photos are uploaded and attached the same way
/// `ApiarySynchronizer`/`HiveSynchronizer` handle theirs, including an
/// orphan-media sweep (see [_syncOrphanMedia]) — [apiaryLocalDataSource] is
/// where the shared `local_media` CRUD lives (mirrors `HiveSynchronizer`'s
/// own dependency on it despite the name).
final class InspectionSynchronizer implements IInspectionSynchronizer {
  InspectionSynchronizer({
    required this.localDataSource,
    required this.hiveLocalDataSource,
    required this.apiaryLocalDataSource,
    required this.inspectionRemoteDataSource,
    required this.mediaRemoteDataSource,
    required this.networkInfo,
    this.refreshNotifier,
  });

  final IInspectionLocalDataSource localDataSource;
  final IHiveLocalDataSource hiveLocalDataSource;
  final IApiaryLocalDataSource apiaryLocalDataSource;
  final IInspectionDataSource inspectionRemoteDataSource;
  final IMediaDataSource mediaRemoteDataSource;
  final INetworkInfo networkInfo;
  final InspectionListRefreshNotifier? refreshNotifier;

  @override
  Future<InspectionSyncResult> syncInspections() async {
    final connected = await networkInfo.isConnected;
    if (!connected) {
      return const InspectionSyncResult(totalPending: 0, syncedCount: 0, failedCount: 0, errors: ['No internet connection']);
    }

    final pending = await localDataSource.getPendingSyncInspections();

    int syncedCount = 0;
    int failedCount = 0;
    int skippedCount = 0;
    final errors = <String>[];

    for (final inspection in pending) {
      final resolved = await _resolveParent(inspection);
      if (resolved == null) {
        // Parent hive still requires sync (or failed this round) — never
        // call the Inspection API for it. It stays pending for the next
        // attempt.
        skippedCount++;
        continue;
      }

      try {
        switch (resolved.syncStatus) {
          case SyncStatus.pendingCreate:
            await _syncPendingCreate(resolved);
            syncedCount++;
            break;
          case SyncStatus.pendingUpdate:
            await _syncPendingUpdate(resolved);
            syncedCount++;
            break;
          case SyncStatus.pendingDelete:
            await _syncPendingDelete(resolved);
            syncedCount++;
            break;
          case SyncStatus.synced:
          case SyncStatus.syncing:
            break;
        }
      } catch (e) {
        failedCount++;
        errors.add('Failed to sync inspection ${resolved.id} (hive ${resolved.hiveId}): $e');
        // Do NOT modify or delete SQLite record! Keep it pending for retry.
      }
    }

    if (syncedCount > 0) {
      refreshNotifier?.notify();
    }

    final orphanSynced = await _syncOrphanMedia();
    if (orphanSynced > 0 && syncedCount == 0) {
      refreshNotifier?.notify();
    }
    syncedCount += orphanSynced;

    return InspectionSyncResult(
      totalPending: pending.length,
      syncedCount: syncedCount,
      failedCount: failedCount,
      skippedCount: skippedCount,
      errors: errors,
    );
  }

  /// Uploads [LocalMedia] rows that are still `pendingCreate` but whose
  /// owner inspection is already `synced` (mirrors
  /// `HiveSynchronizer._syncOrphanMedia`).
  Future<int> _syncOrphanMedia() async {
    final pendingMedia = (await apiaryLocalDataSource.getPendingMedia())
        .where((m) => m.ownerType == MediaOwnerType.inspection.name)
        .toList();
    if (pendingMedia.isEmpty) return 0;

    final grouped = <String, ({Inspection inspection, List<LocalMedia> media})>{};
    for (final media in pendingMedia) {
      if (grouped.containsKey(media.ownerId)) {
        grouped[media.ownerId]!.media.add(media);
        continue;
      }
      final inspection = await localDataSource.getInspectionById(media.ownerId);
      if (inspection == null || inspection.serverId == null || inspection.syncStatus != SyncStatus.synced) {
        continue;
      }
      grouped[media.ownerId] = (inspection: inspection, media: [media]);
    }

    if (grouped.isEmpty) return 0;

    int patchedCount = 0;
    for (final entry in grouped.values) {
      final inspection = entry.inspection;
      final orphans = entry.media;
      try {
        final newServerIds = <String>[];
        for (final media in orphans) {
          final uploadResponse = await mediaRemoteDataSource.uploadMedia(
            filePath: media.localFilePath,
            originalFilename: media.originalFilename,
            contentType: media.contentType,
          );
          await apiaryLocalDataSource.updateLocalMediaStatus(media.localId, SyncStatus.synced, serverId: uploadResponse.id);
          newServerIds.add(uploadResponse.id);
        }

        final hiveId = inspection.hiveServerId ?? inspection.hiveId;
        final current = await inspectionRemoteDataSource.getInspection(hiveId, inspection.serverId!);
        final existingIds = current.images.map((i) => i.id).toSet();
        final allImages = [
          ...existingIds,
          ...newServerIds,
          ...inspection.images.where((id) => !id.startsWith('local-media-') && !existingIds.contains(id)),
        ].toSet().toList();

        final request = InspectionRequest(date: current.date, type: current.type, notes: current.notes, images: allImages);
        final updated = await inspectionRemoteDataSource.updateInspection(hiveId, inspection.serverId!, request);

        await localDataSource.markSynced(
          localId: inspection.localId ?? inspection.id,
          serverId: updated.id,
          images: updated.images.map((i) => i.id).toList(),
        );
        patchedCount++;
      } catch (_) {
        // Leave media and inspection in their current state — will retry on
        // next sync.
      }
    }
    return patchedCount;
  }

  /// Returns [inspection] with its `hiveServerId` resolved and ready to
  /// sync, or `null` if the parent hive isn't there yet — enforcing the
  /// `Hive -> Inspection` ordering regardless of what order [pending] lists
  /// inspections and hives in.
  Future<Inspection?> _resolveParent(Inspection inspection) async {
    final hiveLocalId = inspection.hiveLocalId;
    if (hiveLocalId == null) {
      // Already tracking a real server hive id — nothing to resolve.
      return inspection;
    }

    final parentHive = await hiveLocalDataSource.getHiveById(hiveLocalId);
    if (parentHive == null || parentHive.syncStatus != SyncStatus.synced || parentHive.serverId == null) {
      // Parent still pendingCreate/pendingUpdate/pendingDelete, or its own
      // sync failed this round — this inspection must wait.
      return null;
    }

    // Parent just resolved to a server id — persist it on every inspection
    // still tracking that local hive (not just this one) so a sibling
    // created under the same offline hive resolves in the same pass too.
    await localDataSource.resolveHiveServerId(hiveLocalId: hiveLocalId, hiveServerId: parentHive.serverId!);

    return inspection.copyWith(hiveId: parentHive.serverId, hiveServerId: parentHive.serverId);
  }

  Future<void> _syncPendingCreate(Inspection inspection) async {
    final hiveServerId = inspection.hiveServerId;
    if (hiveServerId == null) {
      // Should be unreachable: `_resolveParent` only returns an inspection
      // once its parent has a server id.
      throw StateError('Cannot sync inspection ${inspection.id}: parent hive has no server id yet');
    }
    final localId = inspection.localId ?? inspection.id;

    // 1. Upload any pending local media first
    final finalMediaIds = <String>[];
    final localMediaList = await apiaryLocalDataSource.getLocalMediaForOwner(localId);

    for (final media in localMediaList) {
      if (media.serverId != null && media.syncStatus == SyncStatus.synced) {
        finalMediaIds.add(media.serverId!);
      } else {
        final uploadResponse = await mediaRemoteDataSource.uploadMedia(
          filePath: media.localFilePath,
          originalFilename: media.originalFilename,
          contentType: media.contentType,
        );
        final serverMediaId = uploadResponse.id;
        await apiaryLocalDataSource.updateLocalMediaStatus(media.localId, SyncStatus.synced, serverId: serverMediaId);
        finalMediaIds.add(serverMediaId);
      }
    }

    for (final imgId in inspection.images) {
      if (!imgId.startsWith('local-media-') && !finalMediaIds.contains(imgId)) {
        finalMediaIds.add(imgId);
      }
    }

    // 2. Call Inspection Service create
    final request = InspectionRequest(
      date: inspection.date,
      type: inspection.type,
      notes: inspection.notes,
      images: finalMediaIds.isNotEmpty ? finalMediaIds : null,
    );
    final response = await inspectionRemoteDataSource.createInspection(hiveServerId, request);

    // 3. Atomically update local record with server ID and mark synced
    await localDataSource.markSynced(localId: localId, serverId: response.id, images: response.images.map((i) => i.id).toList());
  }

  Future<void> _syncPendingUpdate(Inspection inspection) async {
    final serverId = inspection.serverId ?? inspection.id;
    final hiveServerId = inspection.hiveServerId ?? inspection.hiveId;
    final localId = inspection.localId ?? inspection.id;

    // 1. Upload any pending media
    final finalMediaIds = <String>[];
    final localMediaList = await apiaryLocalDataSource.getLocalMediaForOwner(localId);

    for (final media in localMediaList) {
      if (media.serverId != null && media.syncStatus == SyncStatus.synced) {
        finalMediaIds.add(media.serverId!);
      } else {
        final uploadResponse = await mediaRemoteDataSource.uploadMedia(
          filePath: media.localFilePath,
          originalFilename: media.originalFilename,
          contentType: media.contentType,
        );
        await apiaryLocalDataSource.updateLocalMediaStatus(media.localId, SyncStatus.synced, serverId: uploadResponse.id);
        finalMediaIds.add(uploadResponse.id);
      }
    }

    for (final imgId in inspection.images) {
      if (!imgId.startsWith('local-media-') && !finalMediaIds.contains(imgId)) {
        finalMediaIds.add(imgId);
      }
    }

    // 2. Call Inspection Service update
    final request = InspectionRequest(
      date: inspection.date,
      type: inspection.type,
      notes: inspection.notes,
      images: finalMediaIds.isNotEmpty ? finalMediaIds : null,
    );
    final response = await inspectionRemoteDataSource.updateInspection(hiveServerId, serverId, request);

    // 3. Mark synced
    await localDataSource.markSynced(localId: localId, serverId: response.id, images: response.images.map((i) => i.id).toList());
  }

  Future<void> _syncPendingDelete(Inspection inspection) async {
    final serverId = inspection.serverId;
    if (serverId != null && serverId.isNotEmpty) {
      try {
        await inspectionRemoteDataSource.deleteInspection(inspection.hiveServerId ?? inspection.hiveId, serverId);
      } on ServerException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
    }
    await localDataSource.deleteInspectionPermanently(inspection.localId ?? inspection.id);
  }
}
