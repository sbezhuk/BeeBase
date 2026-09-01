import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/enum/local/media_sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAttachment _attachment({
  required String id,
  MediaSyncStatus syncStatus = MediaSyncStatus.synced,
  String? localFilePath,
}) {
  return MediaAttachment(
    id: id,
    ownerType: MediaOwnerType.apiary,
    ownerId: 'apiary-1',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    localFilePath: localFilePath,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    syncStatus: syncStatus,
  );
}

void main() {
  group('isLocalOnly', () {
    test('true for a local-prefixed id (never reached the server)', () {
      expect(_attachment(id: 'local-abc123-xyz').isLocalOnly, isTrue);
    });

    test('false for a server-assigned id', () {
      expect(_attachment(id: 'media-1').isLocalOnly, isFalse);
    });
  });

  group('copyWith', () {
    test('overrides syncStatus while leaving everything else untouched', () {
      final original = _attachment(id: 'media-1');

      final updated = original.copyWith(syncStatus: MediaSyncStatus.failed);

      expect(updated.syncStatus, MediaSyncStatus.failed);
      expect(updated.id, original.id);
      expect(updated.ownerId, original.ownerId);
      expect(updated.originalFilename, original.originalFilename);
    });

    test('overrides localFilePath while leaving syncStatus untouched', () {
      final original = _attachment(id: 'media-1', localFilePath: '/tmp/a.jpg');

      final updated = original.copyWith(localFilePath: '/tmp/b.jpg');

      expect(updated.localFilePath, '/tmp/b.jpg');
      expect(updated.syncStatus, original.syncStatus);
    });

    test('keeps the existing value for an omitted argument', () {
      final original = _attachment(
        id: 'media-1',
        syncStatus: MediaSyncStatus.pending,
      );

      final updated = original.copyWith();

      expect(updated.syncStatus, MediaSyncStatus.pending);
    });
  });

  group('equality', () {
    test('two attachments with identical fields are equal', () {
      expect(_attachment(id: 'media-1'), _attachment(id: 'media-1'));
    });

    test('attachments with different ids are not equal', () {
      expect(_attachment(id: 'media-1') == _attachment(id: 'media-2'), isFalse);
    });
  });
}
