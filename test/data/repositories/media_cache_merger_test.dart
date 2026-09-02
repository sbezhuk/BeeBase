import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/repositories/media_cache_merger.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/enum/local/media_sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

MediaResponse _response({
  required String id,
  MediaOwnerType ownerType = MediaOwnerType.apiary,
  String ownerId = 'apiary-1',
}) {
  return MediaResponse(
    id: id,
    ownerType: ownerType,
    ownerId: ownerId,
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  const merger = MediaCacheMerger();

  final serverItem = _response(id: 'media-1');
  final pendingLocal = _response(id: 'local-pending-1');

  OfflineOperation pendingOp(
    String localEntityId, {
    OperationStatus status = OperationStatus.pending,
  }) {
    return OfflineOperation(
      id: 'op-1',
      entityType: 'media',
      operationType: OperationType.create,
      payload: const {},
      status: status,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      localEntityId: localEntityId,
    );
  }

  group('mergeForIds', () {
    test('replaces the old cache with the fresh server response for the same id', () {
      final stale = _response(id: 'media-1', ownerId: 'apiary-1-old-name');
      final merged = merger.mergeForIds(
        [serverItem],
        [stale],
        ids: const {'media-1'},
        pendingOps: const [],
      );
      expect(merged, [serverItem]);
    });

    test(
      'keeps a not-yet-synced local placeholder alongside the fresh server response',
      () {
        final merged = merger.mergeForIds(
          [serverItem],
          [pendingLocal],
          ids: const {'media-1', 'local-pending-1'},
          pendingOps: [pendingOp('local-pending-1')],
        );
        expect(merged.map((response) => response.id), [
          'media-1',
          'local-pending-1',
        ]);
      },
    );

    test('drops a local placeholder once its operation is synced', () {
      final merged = merger.mergeForIds(
        [serverItem],
        [pendingLocal],
        ids: const {'media-1', 'local-pending-1'},
        pendingOps: [
          pendingOp('local-pending-1', status: OperationStatus.synced),
        ],
      );
      expect(merged.map((response) => response.id), ['media-1']);
    });

    test('carries forward a previously known local cache path onto the fresh '
        'server record for the same id — a bare server response never has '
        'one, so without this a photo forgets it was already downloaded on '
        'every refresh and re-downloads it every time', () {
      final oldCacheEntry = serverItem.copyWith(
        localFilePath: '/media/media-1.jpg',
      );
      final freshFromServer = _response(id: 'media-1');

      final merged = merger.mergeForIds(
        [freshFromServer],
        [oldCacheEntry],
        ids: const {'media-1'},
        pendingOps: const [],
      );

      expect(merged.single.localFilePath, '/media/media-1.jpg');
    });

    test(
      'a server record for an id with no previously known local path stays untouched',
      () {
        final merged = merger.mergeForIds(
          [serverItem],
          const [],
          ids: const {'media-1'},
          pendingOps: const [],
        );

        expect(merged.single.localFilePath, isNull);
      },
    );

    test('leaves every cached row outside the requested ids completely '
        'untouched — fetching one gallery must not silently discard another '
        'owner\'s already-synced, previously cached photos from the single '
        'shared "cached_media" blob', () {
      final otherOwnerSynced = _response(id: 'media-2', ownerId: 'apiary-2');
      final otherOwnerPending = _response(
        id: 'local-pending-2',
        ownerId: 'apiary-2',
      );
      final oldCache = [serverItem, otherOwnerSynced, otherOwnerPending];

      final merged = merger.mergeForIds(
        [serverItem],
        oldCache,
        ids: const {'media-1'},
        pendingOps: [pendingOp('local-pending-2')],
      );

      expect(merged.map((response) => response.id).toSet(), {
        'media-1',
        'media-2',
        'local-pending-2',
      });
    });
  });

  group('toEntities', () {
    test(
      'tags a pending id as MediaSyncStatus.pending and everything else as synced',
      () {
        final entities = merger.toEntities(
          [serverItem, pendingLocal],
          [pendingOp('local-pending-1')],
        );
        final synced = entities.firstWhere(
          (attachment) => attachment.id == 'media-1',
        );
        final pending = entities.firstWhere(
          (attachment) => attachment.id == 'local-pending-1',
        );
        expect(synced.syncStatus, MediaSyncStatus.synced);
        expect(pending.syncStatus, MediaSyncStatus.pending);
      },
    );

    test('tags a failed id as MediaSyncStatus.failed', () {
      final entities = merger.toEntities(
        [pendingLocal],
        [pendingOp('local-pending-1', status: OperationStatus.failed)],
      );
      expect(entities.single.syncStatus, MediaSyncStatus.failed);
    });
  });
}
