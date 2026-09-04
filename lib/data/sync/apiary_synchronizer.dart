import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';


final class ApiarySyncResult {
  const ApiarySyncResult({
    required this.totalPending,
    required this.syncedCount,
    required this.failedCount,
    this.errors = const [],
  });

  final int totalPending;
  final int syncedCount;
  final int failedCount;
  final List<String> errors;

  bool get isSuccess => failedCount == 0 && errors.isEmpty;
}

abstract interface class IApiarySynchronizer {
  Future<ApiarySyncResult> syncApiaries();
}

final class ApiarySynchronizer implements IApiarySynchronizer {
  ApiarySynchronizer({
    required this.localDataSource,
    required this.apiaryRemoteDataSource,
    required this.mediaRemoteDataSource,
    required this.networkInfo,
    this.refreshNotifier,
  });

  final IApiaryLocalDataSource localDataSource;
  final IApiaryDataSource apiaryRemoteDataSource;
  final IMediaDataSource mediaRemoteDataSource;
  final INetworkInfo networkInfo;
  final ApiaryListRefreshNotifier? refreshNotifier;

  @override
  Future<ApiarySyncResult> syncApiaries() async {
    final connected = await networkInfo.isConnected;
    if (!connected) {
      return const ApiarySyncResult(
        totalPending: 0,
        syncedCount: 0,
        failedCount: 0,
        errors: ['No internet connection'],
      );
    }

    final pending = await localDataSource.getPendingSyncApiaries();

    int syncedCount = 0;
    int failedCount = 0;
    final errors = <String>[];

    for (final apiary in pending) {
      try {
        switch (apiary.syncStatus) {
          case SyncStatus.pendingCreate:
            await _syncPendingCreate(apiary);
            syncedCount++;
            break;

          case SyncStatus.pendingUpdate:
            await _syncPendingUpdate(apiary);
            syncedCount++;
            break;

          case SyncStatus.pendingDelete:
            await _syncPendingDelete(apiary);
            syncedCount++;
            break;

          case SyncStatus.synced:
          case SyncStatus.syncing:
            break;
        }
      } catch (e) {
        failedCount++;
        errors.add('Failed to sync apiary ${apiary.name} (${apiary.id}): $e');
        // Do NOT modify or delete SQLite record! Keep it pending for retry.
      }
    }

    if (syncedCount > 0) {
      refreshNotifier?.notify();
    }

    // Safety-net: sweep for LocalMedia rows whose apiary is otherwise `synced`
    // (e.g. photos added offline before the addApiaryImage fix was deployed, or
    // photos on apiaries whose only change was an image attachment).
    final orphanSynced = await _syncOrphanMedia();
    if (orphanSynced > 0 && syncedCount == 0) {
      refreshNotifier?.notify();
    }
    syncedCount += orphanSynced;

    return ApiarySyncResult(
      totalPending: pending.length,
      syncedCount: syncedCount,
      failedCount: failedCount,
      errors: errors,
    );
  }

  /// Uploads [LocalMedia] rows that are still `pendingCreate` but whose owner
  /// apiary is already `synced` (i.e. the apiary never became `pendingUpdate`).
  /// Returns the number of apiaries successfully patched.
  Future<int> _syncOrphanMedia() async {
    final pendingMedia = await localDataSource.getPendingMedia();
    if (pendingMedia.isEmpty) return 0;

    // Group orphan media by ownerId (String), keying by ownerId so that
    // separate calls to getApiaryById() — which return different Apiary instances
    // — don't create duplicate map entries (Apiary has no == / hashCode).
    // Each entry maps ownerId → (resolvedApiary, [localMediaItems]).
    final grouped = <String, ({Apiary apiary, List<LocalMedia> media})>{};
    for (final media in pendingMedia) {
      if (grouped.containsKey(media.ownerId)) {
        grouped[media.ownerId]!.media.add(media);
        continue;
      }
      final apiary = await localDataSource.getApiaryById(media.ownerId);
      // Only process media whose apiary is synced with a known serverId.
      // pendingCreate/Update/Delete apiaries are handled by the main sync loop.
      if (apiary == null ||
          apiary.serverId == null ||
          apiary.syncStatus != SyncStatus.synced) {
        continue;
      }
      grouped[media.ownerId] = (apiary: apiary, media: [media]);
    }

    if (grouped.isEmpty) return 0;

    int patchedCount = 0;
    for (final entry in grouped.values) {
      final apiary = entry.apiary;
      final orphans = entry.media;
      try {
        // 1. Upload each pending media file.
        final newServerIds = <String>[];
        for (final media in orphans) {
          final uploadResponse = await mediaRemoteDataSource.uploadMedia(
            filePath: media.localFilePath,
            originalFilename: media.originalFilename,
            contentType: media.contentType,
          );
          await localDataSource.updateLocalMediaStatus(
            media.localId,
            SyncStatus.synced,
            serverId: uploadResponse.id,
          );
          newServerIds.add(uploadResponse.id);
        }

        // 2. Fetch the current server apiary to avoid clobbering existing images.
        final current = await apiaryRemoteDataSource.getApiary(apiary.serverId!);
        final existingIds = current.images.map((i) => i.id).toSet();
        final allImages = [
          ...existingIds,
          ...newServerIds,
          // Preserve non-local image IDs already stored locally.
          ...apiary.images.where(
            (id) => !id.startsWith('local-media-') && !existingIds.contains(id),
          ),
        ].toSet().toList();

        // 3. Patch the apiary on the server with the merged image list.
        final request = ApiaryRequest(
          name: current.name,
          description: current.description,
          location: current.location,
          lat: current.lat,
          lon: current.lon,
          images: allImages,
        );
        final updated =
            await apiaryRemoteDataSource.updateApiary(apiary.serverId!, request);

        // 4. Persist the server's response back to SQLite.
        await localDataSource.markSynced(
          localId: apiary.localId ?? apiary.id,
          serverId: updated.id,
          images: updated.images.map((i) => i.id).toList(),
        );
        patchedCount++;
      } catch (_) {
        // Leave media and apiary in their current state — will retry on next sync.
      }
    }
    return patchedCount;
  }


  Future<void> _syncPendingCreate(Apiary apiary) async {
    final localId = apiary.localId ?? apiary.id;

    // 1. Upload any pending local media first
    final finalMediaIds = <String>[];
    final localMediaList =
        await localDataSource.getLocalMediaForOwner(localId);

    for (final media in localMediaList) {
      if (media.serverId != null && media.syncStatus == SyncStatus.synced) {
        finalMediaIds.add(media.serverId!);
      } else {
        // Upload media file to media-service
        final uploadResponse = await mediaRemoteDataSource.uploadMedia(
          filePath: media.localFilePath,
          originalFilename: media.originalFilename,
          contentType: media.contentType,
        );
        final serverMediaId = uploadResponse.id;
        await localDataSource.updateLocalMediaStatus(
          media.localId,
          SyncStatus.synced,
          serverId: serverMediaId,
        );
        finalMediaIds.add(serverMediaId);
      }
    }

    // Also include any non-local media IDs that might already be in apiary.images
    for (final imgId in apiary.images) {
      if (!imgId.startsWith('local-media-') && !finalMediaIds.contains(imgId)) {
        finalMediaIds.add(imgId);
      }
    }

    // 2. Call Apiary Service create
    final request = ApiaryRequest(
      name: apiary.name,
      description: apiary.description,
      location: apiary.location,
      lat: apiary.lat,
      lon: apiary.lon,
      images: finalMediaIds.isNotEmpty ? finalMediaIds : null,
    );
    final response = await apiaryRemoteDataSource.createApiary(request);

    // 3. Atomically update local record with server ID and mark synced
    await localDataSource.markSynced(
      localId: localId,
      serverId: response.id,
      images: response.images.map((i) => i.id).toList(),
    );
  }

  Future<void> _syncPendingUpdate(Apiary apiary) async {
    final serverId = apiary.serverId ?? apiary.id;
    final localId = apiary.localId ?? apiary.id;

    // 1. Upload any pending media
    final finalMediaIds = <String>[];
    final localMediaList =
        await localDataSource.getLocalMediaForOwner(localId);

    for (final media in localMediaList) {
      if (media.serverId != null && media.syncStatus == SyncStatus.synced) {
        finalMediaIds.add(media.serverId!);
      } else {
        final uploadResponse = await mediaRemoteDataSource.uploadMedia(
          filePath: media.localFilePath,
          originalFilename: media.originalFilename,
          contentType: media.contentType,
        );
        await localDataSource.updateLocalMediaStatus(
          media.localId,
          SyncStatus.synced,
          serverId: uploadResponse.id,
        );
        finalMediaIds.add(uploadResponse.id);
      }
    }

    for (final imgId in apiary.images) {
      if (!imgId.startsWith('local-media-') && !finalMediaIds.contains(imgId)) {
        finalMediaIds.add(imgId);
      }
    }

    // 2. Call Apiary Service update
    final request = ApiaryRequest(
      name: apiary.name,
      description: apiary.description,
      location: apiary.location,
      lat: apiary.lat,
      lon: apiary.lon,
      images: finalMediaIds.isNotEmpty ? finalMediaIds : null,
    );
    final response =
        await apiaryRemoteDataSource.updateApiary(serverId, request);

    // 3. Mark synced
    await localDataSource.markSynced(
      localId: localId,
      serverId: response.id,
      images: response.images.map((i) => i.id).toList(),
    );
  }

  Future<void> _syncPendingDelete(Apiary apiary) async {
    final serverId = apiary.serverId;
    if (serverId != null && serverId.isNotEmpty) {
      try {
        await apiaryRemoteDataSource.deleteApiary(serverId);
      } on ServerException catch (e) {
        // 404 means already deleted server-side; treat as success
        if (e.statusCode != 404) rethrow;
      }
    }
    // Only permanently remove local row after confirmed server delete
    await localDataSource.deleteApiaryPermanently(apiary.localId ?? apiary.id);
  }
}
