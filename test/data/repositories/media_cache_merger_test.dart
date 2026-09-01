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

  group('mergeFirstPage', () {
    test('replaces the old cache with the fresh server page', () {
      final stale = _response(id: 'stale');
      final merged = merger.mergeFirstPage(
        [serverItem],
        [stale],
        ownerType: MediaOwnerType.apiary,
        ownerIds: const {'apiary-1'},
        pendingOps: const [],
      );
      expect(merged.map((response) => response.id), ['media-1']);
    });

    test(
      'keeps a not-yet-synced local placeholder alongside the fresh server page',
      () {
        final merged = merger.mergeFirstPage(
          [serverItem],
          [pendingLocal],
          ownerType: MediaOwnerType.apiary,
          ownerIds: const {'apiary-1'},
          pendingOps: [pendingOp('local-pending-1')],
        );
        expect(merged.map((response) => response.id), [
          'media-1',
          'local-pending-1',
        ]);
      },
    );

    test('drops a local placeholder once its operation is synced', () {
      final merged = merger.mergeFirstPage(
        [serverItem],
        [pendingLocal],
        ownerType: MediaOwnerType.apiary,
        ownerIds: const {'apiary-1'},
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

      final merged = merger.mergeFirstPage(
        [freshFromServer],
        [oldCacheEntry],
        ownerType: MediaOwnerType.apiary,
        ownerIds: const {'apiary-1'},
        pendingOps: const [],
      );

      expect(merged.single.localFilePath, '/media/media-1.jpg');
    });

    test(
      'a server record for an id with no previously known local path stays untouched',
      () {
        final merged = merger.mergeFirstPage(
          [serverItem],
          const [],
          ownerType: MediaOwnerType.apiary,
          ownerIds: const {'apiary-1'},
          pendingOps: const [],
        );

        expect(merged.single.localFilePath, isNull);
      },
    );

    test('leaves every other owner\'s cached media completely untouched — '
        'fetching one apiary\'s gallery must not silently discard another '
        'apiary\'s (or a hive\'s) already-synced, previously cached photos '
        'from the single shared "cached_media" blob', () {
      final otherOwnerSynced = _response(id: 'media-2', ownerId: 'apiary-2');
      final otherOwnerPending = _response(
        id: 'local-pending-2',
        ownerId: 'apiary-2',
      );
      final oldCache = [serverItem, otherOwnerSynced, otherOwnerPending];

      final merged = merger.mergeFirstPage(
        [serverItem],
        oldCache,
        ownerType: MediaOwnerType.apiary,
        ownerIds: const {'apiary-1'},
        pendingOps: [pendingOp('local-pending-2')],
      );

      expect(merged.map((response) => response.id).toSet(), {
        'media-1',
        'media-2',
        'local-pending-2',
      });
    });

    test('matches a not-yet-synced placeholder still filed under the owner\'s '
        'old local id even when the caller now asks using the owner\'s newly '
        'resolved server id — the "owner synced, this photo did not yet" '
        'window where the two ids briefly coexist for the same owner', () {
      final placeholderUnderOldOwnerId = _response(
        id: 'local-pending-1',
        ownerId: 'local-apiary-1',
      );

      final merged = merger.mergeFirstPage(
        const [],
        [placeholderUnderOldOwnerId],
        ownerType: MediaOwnerType.apiary,
        ownerIds: const {'local-apiary-1', 'srv-apiary-1'},
        pendingOps: [pendingOp('local-pending-1')],
      );

      expect(merged.single.id, 'local-pending-1');
      expect(merged.single.ownerId, 'local-apiary-1');
    });
  });

  group('appendPage', () {
    test(
      'appends the fresh page after the existing cache, preserving order',
      () {
        final second = _response(id: 'media-2');
        final merged = merger.appendPage([second], [serverItem]);
        expect(merged.map((response) => response.id), ['media-1', 'media-2']);
      },
    );

    test(
      'dedupes an item that appears in both the old cache and the fresh page',
      () {
        final merged = merger.appendPage([serverItem], [serverItem]);
        expect(merged.map((response) => response.id), ['media-1']);
      },
    );
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
