import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';

final class HiveSyncResult {
  const HiveSyncResult({
    required this.totalPending,
    required this.syncedCount,
    required this.failedCount,
    this.skippedCount = 0,
    this.errors = const [],
  });

  final int totalPending;
  final int syncedCount;
  final int failedCount;

  /// Hives left pending because their parent apiary still requires
  /// synchronization (or failed to sync this round) — not a failure, just
  /// not yet eligible. Retried on the next sync pass.
  final int skippedCount;
  final List<String> errors;

  bool get isSuccess => failedCount == 0 && errors.isEmpty;
}

abstract interface class IHiveSynchronizer {
  Future<HiveSyncResult> syncHives();
}

/// Synchronizes offline hive changes with hive-service, honoring the strict
/// `Apiary -> Hive` dependency: a hive whose parent apiary hasn't
/// synchronized yet (still tracked by [Hive.apiaryLocalId]) is left pending
/// rather than sent to the backend — see [_resolveParent]. Callers must run
/// [ApiarySynchronizer].syncApiaries() first on each sync pass (see
/// `DataSynchronizer`, the single entry point that guarantees this
/// ordering) so that a parent apiary which just synced is picked up in the
/// same pass instead of requiring a second manual sync.
final class HiveSynchronizer implements IHiveSynchronizer {
  HiveSynchronizer({
    required this.localDataSource,
    required this.apiaryLocalDataSource,
    required this.hiveRemoteDataSource,
    required this.mediaRemoteDataSource,
    required this.networkInfo,
    this.refreshNotifier,
  });

  final IHiveLocalDataSource localDataSource;
  final IApiaryLocalDataSource apiaryLocalDataSource;
  final IHiveDataSource hiveRemoteDataSource;
  final IMediaDataSource mediaRemoteDataSource;
  final INetworkInfo networkInfo;
  final HiveListRefreshNotifier? refreshNotifier;

  @override
  Future<HiveSyncResult> syncHives() async {
    final connected = await networkInfo.isConnected;
    if (!connected) {
      return const HiveSyncResult(
        totalPending: 0,
        syncedCount: 0,
        failedCount: 0,
        errors: ['No internet connection'],
      );
    }

    final pending = await localDataSource.getPendingSyncHives();

    int syncedCount = 0;
    int failedCount = 0;
    int skippedCount = 0;
    final errors = <String>[];

    for (final hive in pending) {
      final resolved = await _resolveParent(hive);
      if (resolved == null) {
        // Parent apiary still requires sync (or failed this round) — never
        // call the Hive API for it. It stays pending for the next attempt.
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
        errors.add('Failed to sync hive ${resolved.name} (${resolved.id}): $e');
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

    return HiveSyncResult(
      totalPending: pending.length,
      syncedCount: syncedCount,
      failedCount: failedCount,
      skippedCount: skippedCount,
      errors: errors,
    );
  }

  /// Returns [hive] with its `apiaryServerId` resolved and ready to sync, or
  /// `null` if the parent apiary isn't there yet — enforcing the
  /// `Apiary -> Hive` ordering regardless of what order [pending] lists
  /// hives and apiaries in.
  Future<Hive?> _resolveParent(Hive hive) async {
    final apiaryLocalId = hive.apiaryLocalId;
    if (apiaryLocalId == null) {
      // Already tracking a real server apiary id — nothing to resolve.
      return hive;
    }

    final parentApiary = await apiaryLocalDataSource.getApiaryById(
      apiaryLocalId,
    );
    if (parentApiary == null ||
        parentApiary.syncStatus != SyncStatus.synced ||
        parentApiary.serverId == null) {
      // Parent still pendingCreate/pendingUpdate/pendingDelete, or its own
      // sync failed this round — this hive must wait.
      return null;
    }

    // Parent just resolved to a server id — persist it on every hive still
    // tracking that local apiary (not just this one) so a sibling created
    // under the same offline apiary resolves in the same pass too.
    await localDataSource.resolveApiaryServerId(
      apiaryLocalId: apiaryLocalId,
      apiaryServerId: parentApiary.serverId!,
    );

    return hive.copyWith(
      apiaryId: parentApiary.serverId,
      apiaryServerId: parentApiary.serverId,
    );
  }

  /// Uploads [LocalMedia] rows that are still `pendingCreate` but whose
  /// owner hive is already `synced` (mirrors `ApiarySynchronizer._syncOrphanMedia`).
  Future<int> _syncOrphanMedia() async {
    final pendingMedia = (await apiaryLocalDataSource.getPendingMedia())
        .where((m) => m.ownerType == MediaOwnerType.hive.name)
        .toList();
    if (pendingMedia.isEmpty) return 0;

    final grouped = <String, ({Hive hive, List<LocalMedia> media})>{};
    for (final media in pendingMedia) {
      if (grouped.containsKey(media.ownerId)) {
        grouped[media.ownerId]!.media.add(media);
        continue;
      }
      final hive = await localDataSource.getHiveById(media.ownerId);
      if (hive == null ||
          hive.serverId == null ||
          hive.syncStatus != SyncStatus.synced) {
        continue;
      }
      grouped[media.ownerId] = (hive: hive, media: [media]);
    }

    if (grouped.isEmpty) return 0;

    int patchedCount = 0;
    for (final entry in grouped.values) {
      final hive = entry.hive;
      final orphans = entry.media;
      try {
        final newServerIds = <String>[];
        for (final media in orphans) {
          final uploadResponse = await mediaRemoteDataSource.uploadMedia(
            filePath: media.localFilePath,
            originalFilename: media.originalFilename,
            contentType: media.contentType,
          );
          await apiaryLocalDataSource.updateLocalMediaStatus(
            media.localId,
            SyncStatus.synced,
            serverId: uploadResponse.id,
          );
          newServerIds.add(uploadResponse.id);
        }

        final current = await hiveRemoteDataSource.getHive(hive.serverId!);
        final existingIds = current.images.map((i) => i.id).toSet();
        final allImages = [
          ...existingIds,
          ...newServerIds,
          ...hive.images.where(
            (id) => !id.startsWith('local-media-') && !existingIds.contains(id),
          ),
        ].toSet().toList();

        final request = HiveRequest(
          name: current.name,
          notes: current.notes,
          images: allImages,
        );
        final updated = await hiveRemoteDataSource.updateHive(
          hive.serverId!,
          request,
        );

        await localDataSource.markSynced(
          localId: hive.localId ?? hive.id,
          serverId: updated.id,
          images: updated.images.map((i) => i.id).toList(),
        );
        patchedCount++;
      } catch (_) {
        // Leave media and hive in their current state — will retry on next sync.
      }
    }
    return patchedCount;
  }

  Future<void> _syncPendingCreate(Hive hive) async {
    final apiaryServerId = hive.apiaryServerId;
    if (apiaryServerId == null) {
      // Should be unreachable: `_resolveParent` only returns a hive once its
      // parent has a server id.
      throw StateError(
        'Cannot sync hive ${hive.id}: parent apiary has no server id yet',
      );
    }
    final localId = hive.localId ?? hive.id;

    final finalMediaIds = <String>[];
    final localMediaList = await apiaryLocalDataSource.getLocalMediaForOwner(
      localId,
    );

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
        await apiaryLocalDataSource.updateLocalMediaStatus(
          media.localId,
          SyncStatus.synced,
          serverId: serverMediaId,
        );
        finalMediaIds.add(serverMediaId);
      }
    }

    for (final imgId in hive.images) {
      if (!imgId.startsWith('local-media-') && !finalMediaIds.contains(imgId)) {
        finalMediaIds.add(imgId);
      }
    }

    final request = HiveRequest(
      name: hive.name,
      notes: hive.notes,
      images: finalMediaIds.isNotEmpty ? finalMediaIds : null,
    );
    final response = await hiveRemoteDataSource.createHive(
      request,
      apiaryId: apiaryServerId,
    );

    await localDataSource.markSynced(
      localId: localId,
      serverId: response.id,
      images: response.images.map((i) => i.id).toList(),
    );
  }

  Future<void> _syncPendingUpdate(Hive hive) async {
    final serverId = hive.serverId ?? hive.id;
    final localId = hive.localId ?? hive.id;

    final finalMediaIds = <String>[];
    final localMediaList = await apiaryLocalDataSource.getLocalMediaForOwner(
      localId,
    );

    for (final media in localMediaList) {
      if (media.serverId != null && media.syncStatus == SyncStatus.synced) {
        finalMediaIds.add(media.serverId!);
      } else {
        final uploadResponse = await mediaRemoteDataSource.uploadMedia(
          filePath: media.localFilePath,
          originalFilename: media.originalFilename,
          contentType: media.contentType,
        );
        await apiaryLocalDataSource.updateLocalMediaStatus(
          media.localId,
          SyncStatus.synced,
          serverId: uploadResponse.id,
        );
        finalMediaIds.add(uploadResponse.id);
      }
    }

    for (final imgId in hive.images) {
      if (!imgId.startsWith('local-media-') && !finalMediaIds.contains(imgId)) {
        finalMediaIds.add(imgId);
      }
    }

    final request = HiveRequest(
      name: hive.name,
      notes: hive.notes,
      images: finalMediaIds.isNotEmpty ? finalMediaIds : null,
    );
    final response = await hiveRemoteDataSource.updateHive(serverId, request);

    await localDataSource.markSynced(
      localId: localId,
      serverId: response.id,
      images: response.images.map((i) => i.id).toList(),
    );
  }

  Future<void> _syncPendingDelete(Hive hive) async {
    final serverId = hive.serverId;
    if (serverId != null && serverId.isNotEmpty) {
      try {
        await hiveRemoteDataSource.deleteHive(serverId);
      } on ServerException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
    }
    await localDataSource.deleteHivePermanently(hive.localId ?? hive.id);
  }
}
