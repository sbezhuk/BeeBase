import 'dart:async';

import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/presentation/connectivity/cubit/connectivity_cubit/connectivity_cubit.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/media/widget/media_gallery_section.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMediaReader extends Mock implements IMediaReader {}

class MockMediaWriter extends Mock implements IMediaWriter {}

class _FakeConnectivityService implements IConnectivityService {
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get status => _controller.stream;

  void emit(bool online) => _controller.add(online);

  Future<void> dispose() => _controller.close();
}

void main() {
  late MockMediaReader reader;
  late MockMediaWriter writer;
  // Built inside the test body (via pumpGallery), not here — a
  // StreamController-backed subscription created in setUp runs outside the
  // testWidgets fake-async zone, so pump() never delivers its events. See
  // connectivity_banner_test.dart for the same fix.
  late _FakeConnectivityService connectivity;
  late ConnectivityCubit connectivityCubit;
  late MediaGalleryCubit galleryCubit;

  final syncedAttachment = MediaAttachment(
    id: 'media-1',
    ownerType: MediaOwnerType.apiary,
    ownerId: 'apiary-1',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 4,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final localOnlyAttachment = MediaAttachment(
    id: 'local-pending-1',
    ownerType: MediaOwnerType.apiary,
    ownerId: 'apiary-1',
    originalFilename: 'photo2.jpg',
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
    await connectivityCubit.close();
    await connectivity.dispose();
  });

  Future<void> pumpGallery(WidgetTester tester, MediaAttachment attachment) async {
    when(
      () => reader.getMedia(
        ownerType: any(named: 'ownerType'),
        ownerId: any(named: 'ownerId'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => Right(Page(items: [attachment], hasNext: false)));
    when(() => reader.cacheDownloadedMedia(any(), any())).thenAnswer((_) async {});

    galleryCubit = MediaGalleryCubit(
      reader: reader,
      writer: writer,
      localMediaStore: const LocalMediaStore(),
      ownerType: MediaOwnerType.apiary,
      ownerId: 'apiary-1',
    );
    await galleryCubit.load();

    connectivity = _FakeConnectivityService();
    connectivityCubit = ConnectivityCubit(connectivity: connectivity);

    // Taller than the default 800x600 test surface so the confirmation
    // sheet's content fits without overflowing/landing off-screen.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ConnectivityCubit>.value(value: connectivityCubit),
              BlocProvider<MediaGalleryCubit>.value(value: galleryCubit),
            ],
            child: const MediaGallerySection(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  GestureDetector removeButtonDetector(WidgetTester tester) {
    return tester.widget<GestureDetector>(find.ancestor(of: find.byIcon(Icons.close), matching: find.byType(GestureDetector)));
  }

  // Discrete pumps throughout this file, never pumpAndSettle — MediaThumbnail
  // never fully settles (see media_thumbnail_test.dart), so pumpAndSettle
  // hangs anywhere in this widget tree.
  //
  // The confirm button is invoked directly via its InkWell.onTap rather than
  // a simulated tap: the sheet's entrance transition, layered on top of
  // MediaThumbnail's own perpetual rebuilds, leaves its hit-test geometry
  // unreliable at any fixed pump duration, even though the button is
  // genuinely visible and correctly labelled on screen.
  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 300));
    final button = tester.widget<InkWell>(find.ancestor(of: find.text('media.gallery.delete'), matching: find.byType(InkWell)));
    button.onTap!();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('an already-synced photo (exists on the server)', () {
    testWidgets('the remove button is hidden entirely while offline', (tester) async {
      await pumpGallery(tester, syncedAttachment);

      connectivity.emit(false);
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('the remove action works normally while online', (tester) async {
      when(() => writer.removeMedia('media-1')).thenAnswer((_) async => const Right(null));
      await pumpGallery(tester, syncedAttachment);

      expect(removeButtonDetector(tester).onTap, isNotNull);
      expect(find.byTooltip('media.gallery.remove'), findsOneWidget);

      await confirmDelete(tester);
      verify(() => writer.removeMedia('media-1')).called(1);
    });

    testWidgets('the remove button reappears once back online', (tester) async {
      when(() => writer.removeMedia('media-1')).thenAnswer((_) async => const Right(null));
      await pumpGallery(tester, syncedAttachment);

      connectivity.emit(false);
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNothing);

      connectivity.emit(true);
      await tester.pump();
      await tester.pump();
      expect(removeButtonDetector(tester).onTap, isNotNull);

      await confirmDelete(tester);
      verify(() => writer.removeMedia('media-1')).called(1);
    });

    testWidgets('tapping remove shows a confirmation sheet before deleting anything', (tester) async {
      await pumpGallery(tester, syncedAttachment);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('media.gallery.deleteConfirmTitle'), findsOneWidget);
      verifyNever(() => writer.removeMedia(any()));
    });

    testWidgets('cancelling the confirmation sheet does not delete the photo', (tester) async {
      await pumpGallery(tester, syncedAttachment);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 300));
      final cancelButton = tester.widget<InkWell>(
        find.ancestor(of: find.text('media.gallery.cancel'), matching: find.byType(InkWell)),
      );
      cancelButton.onTap!();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('media.gallery.deleteConfirmTitle'), findsNothing);
      verifyNever(() => writer.removeMedia(any()));
    });
  });

  group('a photo attached offline and not yet synchronized', () {
    testWidgets('the remove action stays enabled while offline', (tester) async {
      when(() => writer.removeMedia('local-pending-1')).thenAnswer((_) async => const Right(null));
      await pumpGallery(tester, localOnlyAttachment);

      connectivity.emit(false);
      await tester.pump();
      await tester.pump();

      expect(removeButtonDetector(tester).onTap, isNotNull);
      expect(find.byTooltip('media.gallery.remove'), findsOneWidget);

      await confirmDelete(tester);
      verify(() => writer.removeMedia('local-pending-1')).called(1);
    });
  });
}
