import 'package:beebase/presentation/media/widget/cached_media_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCacheManager extends Mock implements BaseCacheManager {}

const _imageUrl = 'https://api.beebase.test/api/v1/media/media-1/download';

void main() {
  late MockCacheManager cacheManager;

  setUp(() {
    cacheManager = MockCacheManager();
    // Left hanging deliberately: these tests are about which *source* the
    // widget picks, not about what a completed download renders as.
    when(
      () => cacheManager.getFileStream(
        any(),
        key: any(named: 'key'),
        headers: any(named: 'headers'),
        withProgress: any(named: 'withProgress'),
      ),
    ).thenAnswer((_) => const Stream<FileResponse>.empty());
  });

  Future<void> pump(
    WidgetTester tester, {
    required String? imageUrl,
    required String? localFilePath,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CachedMediaImage(
            imageUrl: imageUrl,
            localFilePath: localFilePath,
            width: 72,
            height: 72,
            cacheManager: cacheManager,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'a photo with no imageUrl yet renders from its offline original — this is '
    'what keeps a picture taken offline visible before its upload syncs',
    (tester) async {
      await pump(
        tester,
        imageUrl: null,
        localFilePath: '/tmp/cached_media_image_test_photo.jpg',
      );

      expect(find.byType(CachedNetworkImage), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as FileImage).file.path,
        '/tmp/cached_media_image_test_photo.jpg',
      );
    },
  );

  testWidgets('an uploaded photo renders from its imageUrl through the shared '
      'image cache, never a second local copy', (tester) async {
    await pump(tester, imageUrl: _imageUrl, localFilePath: null);

    final cached = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(cached.imageUrl, _imageUrl);
    expect(cached.cacheKey, _imageUrl);
  });

  testWidgets(
    'imageUrl wins over a leftover local path — an already-released original '
    'is gone from disk, so rendering it would show a broken image',
    (tester) async {
      await pump(
        tester,
        imageUrl: _imageUrl,
        localFilePath: '/tmp/cached_media_image_test_released.jpg',
      );

      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is FileImage),
        findsNothing,
      );
    },
  );

  testWidgets('with neither source, the error frame is shown rather than an '
      'empty hole in the layout', (tester) async {
    await pump(tester, imageUrl: null, localFilePath: null);

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('a caller-supplied error widget replaces the default frame — how '
      'ProfileAvatar keeps its person icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CachedMediaImage(
            imageUrl: null,
            localFilePath: null,
            errorWidget: const Icon(Icons.person),
            cacheManager: cacheManager,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });
}
