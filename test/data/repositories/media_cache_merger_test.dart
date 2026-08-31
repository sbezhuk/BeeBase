import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/repositories/media_cache_merger.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/domain/enum/media_sync_status.dart';
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
      final merged = merger.mergeFirstPage([serverItem], [stale], const []);
      expect(merged.map((response) => response.id), ['media-1']);
    });

    test(
      'keeps a not-yet-synced local placeholder alongside the fresh server page',
      () {
        final merged = merger.mergeFirstPage([serverItem], [pendingLocal], [
          pendingOp('local-pending-1'),
        ]);
        expect(merged.map((response) => response.id), [
          'media-1',
          'local-pending-1',
        ]);
      },
    );

    test('drops a local placeholder once its operation is synced', () {
      final merged = merger.mergeFirstPage([serverItem], [pendingLocal], [
        pendingOp('local-pending-1', status: OperationStatus.synced),
      ]);
      expect(merged.map((response) => response.id), ['media-1']);
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
