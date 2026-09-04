import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_item.dart';
import 'package:beebase/presentation/media/widget/cached_media_image.dart';
import 'package:beebase/presentation/media/widget/media_thumbnail.dart';
import 'package:beebase/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCacheManager extends Mock implements BaseCacheManager {}

MediaAttachment _attachment({required String id, String? imageUrl}) {
  return MediaAttachment(
    id: id,
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 4,
    imageUrl: imageUrl,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  // `CachedMediaImage` resolves the app-wide image cache from `di` on its
  // remote branch; a mock keeps this widget test off sqflite and the
  // filesystem, and left unstubbed it never completes a download — which is
  // fine, since these tests are about which source is chosen, not what a
  // finished download paints.
  setUp(() {
    final cacheManager = MockCacheManager();
    when(
      () => cacheManager.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((_) => const Stream<FileResponse>.empty());
    di.registerSingleton<BaseCacheManager>(cacheManager);
  });

  tearDown(di.reset);

  Future<void> pump(WidgetTester tester, MediaGalleryItem item) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MediaThumbnail(item: item))),
    );
  }

  testWidgets(
    'hands a still-staged pick to CachedMediaImage as a local file with no '
    'URL — nothing to fetch until its upload syncs',
    (tester) async {
      await pump(
        tester,
        const MediaGalleryItem(
          localId: 'local-placeholder-1',
          localFilePath: '/tmp/media_thumbnail_test_a.jpg',
          originalFilename: 'a.jpg',
          contentType: 'image/jpeg',
          status: MediaGalleryItemStatus.staged,
        ),
      );

      final image = tester.widget<CachedMediaImage>(
        find.byType(CachedMediaImage),
      );
      expect(image.imageUrl, isNull);
      expect(image.localFilePath, '/tmp/media_thumbnail_test_a.jpg');
    },
  );

  testWidgets(
    'swapping in the server-synced replacement (same slot, different '
    'localId — what MediaGalleryCubit.load() produces once a photo '
    "finishes uploading) switches the source to the attachment's imageUrl",
    (tester) async {
      await pump(
        tester,
        const MediaGalleryItem(
          localId: 'local-placeholder-1',
          localFilePath: '/tmp/media_thumbnail_test_a.jpg',
          originalFilename: 'a.jpg',
          contentType: 'image/jpeg',
          status: MediaGalleryItemStatus.staged,
        ),
      );

      await pump(
        tester,
        MediaGalleryItem(
          localId: 'server-media-1',
          originalFilename: 'a.jpg',
          contentType: 'image/jpeg',
          status: MediaGalleryItemStatus.synced,
          attachment: _attachment(
            id: 'server-media-1',
            imageUrl:
                'https://api.beebase.test/api/v1/media/server-media-1/download',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final image = tester.widget<CachedMediaImage>(
        find.byType(CachedMediaImage),
      );
      expect(
        image.imageUrl,
        'https://api.beebase.test/api/v1/media/server-media-1/download',
      );
      expect(image.localFilePath, isNull);
    },
  );

  testWidgets('an in-flight upload keeps the busy overlay over the photo', (
    tester,
  ) async {
    await pump(
      tester,
      const MediaGalleryItem(
        localId: 'local-placeholder-1',
        localFilePath: '/tmp/media_thumbnail_test_a.jpg',
        originalFilename: 'a.jpg',
        contentType: 'image/jpeg',
        status: MediaGalleryItemStatus.uploading,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
