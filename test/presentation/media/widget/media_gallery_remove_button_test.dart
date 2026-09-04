import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/media/widget/media_gallery_section.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMediaReader extends Mock implements IMediaReader {}

class MockMediaWriter extends Mock implements IMediaWriter {}

void main() {
  late MockMediaReader reader;
  late MockMediaWriter writer;
  late MediaGalleryCubit galleryCubit;

  final attachment = MediaAttachment(
    id: 'media-1',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 4,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(MediaOwnerType.apiary);
  });

  setUp(() {
    reader = MockMediaReader();
    writer = MockMediaWriter();
  });

  tearDown(() async {
    await galleryCubit.close();
  });

  Future<void> pumpGallery(
    WidgetTester tester,
    MediaAttachment attachment,
  ) async {
    when(
      () => reader.getMedia(ids: any(named: 'ids')),
    ).thenAnswer((_) async => Right([attachment]));

    galleryCubit = MediaGalleryCubit(
      reader: reader,
      writer: writer,
      ownerType: MediaOwnerType.apiary,
      ownerId: 'apiary-1',
      resolveImages: (_) async => [attachment.id],
    );
    await galleryCubit.load();

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<MediaGalleryCubit>.value(
            value: galleryCubit,
            child: const MediaGallerySection(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  GestureDetector removeButtonDetector(WidgetTester tester) {
    return tester.widget<GestureDetector>(
      find.ancestor(
        of: find.byIcon(Icons.close),
        matching: find.byType(GestureDetector),
      ),
    );
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 300));
    final button = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('media.gallery.delete'),
        matching: find.byType(InkWell),
      ),
    );
    button.onTap!();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('remove button interaction', () {
    testWidgets('shows remove button and invokes remove on confirmation', (tester) async {
      when(
        () => writer.removeMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          id: 'media-1',
        ),
      ).thenAnswer((_) async => const Right(null));

      await pumpGallery(tester, attachment);

      expect(removeButtonDetector(tester).onTap, isNotNull);
      expect(find.byTooltip('media.gallery.remove'), findsOneWidget);

      await confirmDelete(tester);
      verify(
        () => writer.removeMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          id: 'media-1',
        ),
      ).called(1);
    });

    testWidgets('tapping remove shows confirmation sheet', (tester) async {
      await pumpGallery(tester, attachment);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('media.gallery.delete_confirm_title'), findsOneWidget);
      verifyNever(
        () => writer.removeMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          id: any(named: 'id'),
        ),
      );
    });

    testWidgets('cancelling the confirmation sheet does not delete the photo', (tester) async {
      await pumpGallery(tester, attachment);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 300));
      final cancelButton = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('media.gallery.cancel'),
          matching: find.byType(InkWell),
        ),
      );
      cancelButton.onTap!();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('media.gallery.delete_confirm_title'), findsNothing);
      verifyNever(
        () => writer.removeMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          id: any(named: 'id'),
        ),
      );
    });
  });
}
