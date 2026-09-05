import 'dart:io';

import 'package:beebase/core/media/media_image_cache.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/interface/media_data_source.dart';
import 'package:beebase/data/models/extensions/media_extension.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/domain/entity/local_media.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/domain/repositories/owner_image_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';

final class MediaRepositoryImpl extends Repository
    implements IMediaReader, IMediaWriter {
  MediaRepositoryImpl({
    required this.dataSource,
    required this.imageCache,
    required this.ownerImageWriter,
    this.localDataSource,
    this.networkInfo,
  });

  final IMediaDataSource dataSource;
  final IMediaImageCache imageCache;
  final IOwnerImageWriter ownerImageWriter;
  final IApiaryLocalDataSource? localDataSource;
  final INetworkInfo? networkInfo;

  Future<bool> get _isOnline async =>
      networkInfo == null || await networkInfo!.isConnected;

  @override
  Future<Either<Failure, List<MediaAttachment>>> getMedia({
    required List<String> ids,
  }) async {
    if (ids.isEmpty) {
      return const Right([]);
    }

    return on(() async {
      final online = await _isOnline;

      // Collect local-SQLite media first — these have a local file path we
      // must preserve so `CachedMediaImage` can render offline photos even
      // after navigating away and back to a page (at which point the cubit
      // reloads from the DB rather than keeping the in-memory staged item).
      final localMediaMap = <String, LocalMedia>{};
      if (localDataSource != null) {
        for (final id in ids) {
          final local = await localDataSource!.getLocalMediaById(id);
          if (local != null) localMediaMap[id] = local;
        }
      }

      if (!online) {
        // Offline: return only what we have locally, preserving localFilePath.
        return <MediaAttachment>[
          for (final id in ids)
            if (localMediaMap[id] != null)
              MediaAttachment(
                id: localMediaMap[id]!.localId,
                originalFilename: localMediaMap[id]!.originalFilename,
                contentType: localMediaMap[id]!.contentType,
                sizeBytes: localMediaMap[id]!.sizeBytes,
                imageUrl: null,
                localFilePath: localMediaMap[id]!.localFilePath,
                createdAt: localMediaMap[id]!.createdAt,
                updatedAt: localMediaMap[id]!.createdAt,
              ),
        ];
      }

      // Online: fetch server ids, skip ones we already have locally.
      final remoteIds = ids.where((id) => !localMediaMap.containsKey(id)).toList();
      final remoteItems = remoteIds.isNotEmpty
          ? await dataSource.listMedia(ids: remoteIds)
          : <MediaResponse>[];

      // Cache remote media for offline viewing.
      if (localDataSource != null) {
        for (final item in remoteItems) {
          if (item.imageUrl != null) {
            final cachedPath = await imageCache.getCachedFilePath(item.imageUrl!);
            if (cachedPath != null) {
              final localMedia = LocalMedia(
                localId: item.id,
                serverId: item.id,
                ownerType: '',
                ownerId: '',
                localFilePath: cachedPath,
                originalFilename: item.originalFilename,
                contentType: item.contentType,
                sizeBytes: item.sizeBytes,
                syncStatus: SyncStatus.synced,
                createdAt: item.createdAt,
              );
              await localDataSource!.saveLocalMedia(localMedia);
              localMediaMap[item.id] = localMedia;
            }
          }
        }
      }

      // Merge remote + local, preserving localFilePath for offline items.
      final byId = {for (final r in remoteItems) r.id: r};
      return <MediaAttachment>[
        for (final id in ids)
          if (localMediaMap[id] != null)
            MediaAttachment(
              id: localMediaMap[id]!.localId,
              originalFilename: localMediaMap[id]!.originalFilename,
              contentType: localMediaMap[id]!.contentType,
              sizeBytes: localMediaMap[id]!.sizeBytes,
              imageUrl: byId[id]?.imageUrl,
              localFilePath: localMediaMap[id]!.localFilePath,
              createdAt: localMediaMap[id]!.createdAt,
              updatedAt: localMediaMap[id]!.createdAt,
            )
          else if (byId[id] != null)
            byId[id]!.toEntity(),
      ];
    });
  }


  @override
  Future<Either<Failure, MediaAttachment>> attachMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String localFilePath,
    required String originalFilename,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final online = await _isOnline;

    if (!online && localDataSource != null) {
      final localId = 'local-media-${DateTime.now().microsecondsSinceEpoch}';
      final file = File(localFilePath);
      final sizeBytes = file.existsSync() ? file.lengthSync() : 0;
      final localMedia = LocalMedia(
        localId: localId,
        ownerType: ownerType.name,
        ownerId: ownerId,
        localFilePath: localFilePath,
        originalFilename: originalFilename,
        contentType: contentType,
        sizeBytes: sizeBytes,
        syncStatus: SyncStatus.pendingCreate,
        createdAt: DateTime.now(),
      );
      await localDataSource!.saveLocalMedia(localMedia);

      final addResult = await ownerImageWriter.addImage(
        ownerType: ownerType,
        ownerId: ownerId,
        mediaId: localId,
      );

      return addResult.fold(
        Left.new,
        (_) => Right(
          MediaAttachment(
            id: localId,
            originalFilename: originalFilename,
            contentType: contentType,
            sizeBytes: sizeBytes,
            imageUrl: null,
            localFilePath: localFilePath,
            createdAt: localMedia.createdAt,
            updatedAt: localMedia.createdAt,
          ),
        ),
      );
    }

    final result = await on(() async {
      final uploaded = await dataSource.uploadMedia(
        filePath: localFilePath,
        originalFilename: originalFilename,
        contentType: contentType,
        onSendProgress: onProgress == null
            ? null
            : (sent, total) => onProgress(total <= 0 ? 0 : sent / total),
      );
      await _seedImageCache(uploaded, localFilePath);
      return uploaded;
    });

    return result.fold(Left.new, (uploaded) async {
      final addResult = await ownerImageWriter.addImage(
        ownerType: ownerType,
        ownerId: ownerId,
        mediaId: uploaded.id,
      );
      return addResult.fold(Left.new, (_) => Right(uploaded.toEntity()));
    });
  }

  Future<void> _seedImageCache(MediaResponse uploaded, String localFilePath) {
    final imageUrl = uploaded.imageUrl;
    if (imageUrl == null) {
      return Future.value();
    }
    return imageCache.seedFromFile(imageUrl: imageUrl, filePath: localFilePath);
  }

  @override
  Future<Either<Failure, void>> removeMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String id,
  }) async {
    final online = await _isOnline;

    if (!online && localDataSource != null) {
      final isLocalOnly =
          id.startsWith('local-media-') || id.startsWith('staged-');
      if (!isLocalOnly) {
        return Left(
          ServerFailure(
            code: 'cannot_delete_offline',
            message: 'Photos from online objects cannot be deleted offline.',
          ),
        );
      }
      final detachResult = await ownerImageWriter.removeImage(
        ownerType: ownerType,
        ownerId: ownerId,
        mediaId: id,
      );
      return detachResult.fold(Left.new, (_) async {
        await localDataSource!.deleteLocalMedia(id);
        return const Right(null);
      });
    }

    final detachResult = await ownerImageWriter.removeImage(
      ownerType: ownerType,
      ownerId: ownerId,
      mediaId: id,
    );

    return detachResult.fold(Left.new, (_) async {
      final imageUrl = await _imageUrlOf(id);
      final result = await on(
        () => dataSource.deleteMedia(id),
        ignoreStatusCode: 404,
        onIgnoredStatusCode: () {},
      );

      return result.fold((failure) async => Left(failure), (_) async {
        if (imageUrl != null) {
          await imageCache.evict(imageUrl);
        }
        if (localDataSource != null) {
          await localDataSource!.deleteLocalMedia(id);
        }
        return const Right(null);
      });
    });
  }


  Future<String?> _imageUrlOf(String id) async {
    final result = await on(() => dataSource.listMedia(ids: [id]));
    return result.fold(
      (_) => null,
      (items) => items.isEmpty ? null : items.first.imageUrl,
    );
  }
}
