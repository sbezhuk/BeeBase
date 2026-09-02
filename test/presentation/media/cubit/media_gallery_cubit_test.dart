import 'dart:async';
import 'dart:typed_data';

import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_item.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class MockMediaReader extends Mock implements IMediaReader {}

class MockMediaWriter extends Mock implements IMediaWriter {}

class MockLocalMediaStore extends Mock implements LocalMediaStore {}

class MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late MockMediaReader reader;
  late MockMediaWriter writer;
  late MockLocalMediaStore localMediaStore;
  late MockImagePicker imagePicker;

  final attachment = MediaAttachment(
    id: 'media-1',
    ownerType: MediaOwnerType.apiary,
    ownerId: 'apiary-1',
    originalFilename: 'photo.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 4,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(MediaOwnerType.apiary);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(ImageSource.gallery);
  });

  setUp(() {
    reader = MockMediaReader();
    writer = MockMediaWriter();
    localMediaStore = MockLocalMediaStore();
    imagePicker = MockImagePicker();
    when(
      () => localMediaStore.save(
        any(),
        id: any(named: 'id'),
        extension: any(named: 'extension'),
      ),
    ).thenAnswer(
      (invocation) async => '/tmp/${invocation.namedArguments[#id]}.jpg',
    );
    when(() => localMediaStore.delete(any())).thenAnswer((_) async {});
    when(
      () => localMediaStore.validExistingPath(
        any(),
        extension: any(named: 'extension'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => reader.cacheDownloadedMedia(any(), any()),
    ).thenAnswer((_) async {});
  });

  MediaGalleryCubit buildCubit({
    String? ownerId,
    List<String> images = const [],
  }) {
    return MediaGalleryCubit(
      reader: reader,
      writer: writer,
      localMediaStore: localMediaStore,
      ownerType: MediaOwnerType.apiary,
      ownerId: ownerId,
      imagePicker: imagePicker,
      resolveImages: (_) async => images,
    );
  }

  void stubPick([XFile? file]) {
    when(
      () => imagePicker.pickImage(
        source: any(named: 'source'),
        maxWidth: any(named: 'maxWidth'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer(
      (_) async =>
          file ??
          XFile.fromData(Uint8List.fromList([1, 2, 3, 4]), path: 'photo.jpg'),
    );
  }

  void stubAttach(Either<Failure, MediaAttachment> result) {
    when(
      () => writer.attachMedia(
        ownerType: any(named: 'ownerType'),
        ownerId: any(named: 'ownerId'),
        localFilePath: any(named: 'localFilePath'),
        originalFilename: any(named: 'originalFilename'),
        contentType: any(named: 'contentType'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => result);
  }

  group('staging mode (ownerId == null)', () {
    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'load() goes straight to an empty Loaded list, no reader call',
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [const MediaGalleryLoaded([])],
      verify: (_) => verifyNever(
        () => reader.getMedia(ids: any(named: 'ids')),
      ),
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'pickFromGallery stages the file locally without calling attachMedia',
      build: buildCubit,
      act: (cubit) async {
        stubPick();
        await cubit.pickFromGallery();
      },
      verify: (cubit) {
        final state = cubit.state as MediaGalleryLoaded;
        expect(state.items.single.status, MediaGalleryItemStatus.staged);
        expect(cubit.hasStagedPhotos, isTrue);
        verifyNever(
          () => writer.attachMedia(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            localFilePath: any(named: 'localFilePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            onProgress: any(named: 'onProgress'),
          ),
        );
      },
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'a cancelled pick (null result) is a no-op',
      build: buildCubit,
      act: (cubit) async {
        stubPick(null);
        when(
          () => imagePicker.pickImage(
            source: any(named: 'source'),
            maxWidth: any(named: 'maxWidth'),
            imageQuality: any(named: 'imageQuality'),
          ),
        ).thenAnswer((_) async => null);
        await cubit.takePhoto();
      },
      expect: () => <MediaGalleryState>[],
    );

    test(
      'commitChanges flushes staged items through attachMedia and updates their status to the result',
      () async {
        stubPick();
        stubAttach(Right(attachment));
        final cubit = buildCubit();
        await cubit.pickFromGallery();
        expect(cubit.hasStagedPhotos, isTrue);

        await cubit.commitChanges(MediaOwnerType.apiary, 'apiary-1');

        final state = cubit.state as MediaGalleryLoaded;
        expect(state.items.single.status, MediaGalleryItemStatus.synced);
        expect(state.items.single.attachment, attachment);
        expect(cubit.hasStagedPhotos, isFalse);
        verify(
          () => writer.attachMedia(
            ownerType: MediaOwnerType.apiary,
            ownerId: 'apiary-1',
            localFilePath: any(named: 'localFilePath'),
            originalFilename: 'photo.jpg',
            contentType: any(named: 'contentType'),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
        await cubit.close();
      },
    );

    test(
      'a failed commitChanges upload marks the item failed with an error message',
      () async {
        stubPick();
        stubAttach(
          Left(ServerFailure(code: 'file_too_large', message: 'too big')),
        );
        final cubit = buildCubit();
        await cubit.pickFromGallery();

        await cubit.commitChanges(MediaOwnerType.apiary, 'apiary-1');

        final state = cubit.state as MediaGalleryLoaded;
        expect(state.items.single.status, MediaGalleryItemStatus.failed);
        expect(state.items.single.errorMessage, isNotNull);
        await cubit.close();
      },
    );

    test(
      'remove() on a staged item deletes the local file and drops it from the list, no network call',
      () async {
        stubPick();
        final cubit = buildCubit();
        await cubit.pickFromGallery();
        final localId =
            (cubit.state as MediaGalleryLoaded).items.single.localId;

        await cubit.remove(localId);

        expect((cubit.state as MediaGalleryLoaded).items, isEmpty);
        verify(() => localMediaStore.delete(any())).called(1);
        verifyNever(() => writer.removeMedia(any()));
        await cubit.close();
      },
    );
  });

  group('draft creation (configureDraftCreation)', () {
    test(
      'a pick resolves the owner id via the configured callback and uploads immediately, instead of staying staged',
      () async {
        stubPick();
        stubAttach(Right(attachment));
        final cubit = buildCubit();
        cubit.configureDraftCreation(() async => 'apiary-1');

        await cubit.pickFromGallery();

        final state = cubit.state as MediaGalleryLoaded;
        expect(state.items.single.status, MediaGalleryItemStatus.synced);
        verify(
          () => writer.attachMedia(
            ownerType: MediaOwnerType.apiary,
            ownerId: 'apiary-1',
            localFilePath: any(named: 'localFilePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
        await cubit.close();
      },
    );

    test(
      'a second pick reuses the owner id resolved by the first instead of calling the draft callback again',
      () async {
        stubPick();
        stubAttach(Right(attachment));
        final cubit = buildCubit();
        var draftCalls = 0;
        cubit.configureDraftCreation(() async {
          draftCalls++;
          return 'apiary-1';
        });

        await cubit.pickFromGallery();
        await cubit.pickFromGallery();

        expect(draftCalls, 1);
        expect((cubit.state as MediaGalleryLoaded).items, hasLength(2));
        await cubit.close();
      },
    );

    test(
      'a draft callback that fails to resolve an owner id leaves the photo staged, not failed',
      () async {
        stubPick();
        final cubit = buildCubit();
        cubit.configureDraftCreation(() async => null);

        await cubit.pickFromGallery();

        final state = cubit.state as MediaGalleryLoaded;
        expect(state.items.single.status, MediaGalleryItemStatus.staged);
        expect(cubit.hasStagedPhotos, isTrue);
        verifyNever(
          () => writer.attachMedia(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            localFilePath: any(named: 'localFilePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            onProgress: any(named: 'onProgress'),
          ),
        );
        await cubit.close();
      },
    );

    test(
      'a live-mode cubit (ownerId already set) never calls the draft callback even if one is configured',
      () async {
        stubPick();
        stubAttach(Right(attachment));
        final cubit = buildCubit(ownerId: 'apiary-1');
        var draftCalls = 0;
        cubit.configureDraftCreation(() async {
          draftCalls++;
          return 'should-not-be-used';
        });

        await cubit.pickFromGallery();

        expect(draftCalls, 0);
        await cubit.close();
      },
    );
  });

  group('live mode (ownerId != null)', () {
    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'load() fetches already-attached photos and maps their sync status',
      build: () {
        when(
          () => reader.getMedia(ids: ['media-1']),
        ).thenAnswer((_) async => Right([attachment]));
        return buildCubit(ownerId: 'apiary-1', images: ['media-1']);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const MediaGalleryLoading(),
        isA<MediaGalleryLoaded>()
            .having((s) => s.items.single.attachment, 'attachment', attachment)
            .having(
              (s) => s.items.single.status,
              'status',
              MediaGalleryItemStatus.synced,
            ),
      ],
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'a second load() while already Loaded (e.g. a background refresh '
      'triggered by ownerListChanges after an upload) does not re-emit '
      'MediaGalleryLoading — that would flash the gallery/preview blank for '
      'a moment even though it already has correct data to show. Uses a '
      'genuinely different second result so the fold-through-to-Loaded '
      'emission isn\'t itself swallowed by MediaGalleryLoaded\'s value '
      'equality (a same-content refresh legitimately emits nothing at all).',
      build: () {
        var callCount = 0;
        final secondAttachment = MediaAttachment(
          id: 'media-2',
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          originalFilename: 'photo2.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 8,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        when(
          () => reader.getMedia(ids: any(named: 'ids')),
        ).thenAnswer((_) async {
          callCount++;
          final items = callCount == 1
              ? [attachment]
              : [attachment, secondAttachment];
          return Right(items);
        });
        return buildCubit(ownerId: 'apiary-1', images: ['media-1', 'media-2']);
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.load();
      },
      skip: 2, // the first load()'s Loading + Loaded
      expect: () => [
        isA<MediaGalleryLoaded>().having(
          (state) => state.items.length,
          'items.length',
          2,
        ),
      ],
    );

    blocTest<MediaGalleryCubit, MediaGalleryState>(
      'a failed load emits MediaGalleryError',
      build: () {
        when(
          () => reader.getMedia(ids: any(named: 'ids')),
        ).thenAnswer(
          (_) async =>
              const Left(InternalFailure(ErrorTextRaw('no connection'))),
        );
        return buildCubit(ownerId: 'apiary-1', images: ['media-1']);
      },
      act: (cubit) => cubit.load(),
      expect: () => [const MediaGalleryLoading(), isA<MediaGalleryError>()],
    );

    test('pickFromGallery uploads immediately instead of staging', () async {
      stubPick();
      stubAttach(Right(attachment));
      final cubit = buildCubit(ownerId: 'apiary-1');

      await cubit.pickFromGallery();

      final state = cubit.state as MediaGalleryLoaded;
      expect(state.items.single.status, MediaGalleryItemStatus.synced);
      verify(
        () => writer.attachMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          localFilePath: any(named: 'localFilePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      await cubit.close();
    });

    test(
      'remove() on a synced item calls removeMedia and drops it from the list on success',
      () async {
        when(
          () => reader.getMedia(ids: any(named: 'ids')),
        ).thenAnswer((_) async => Right([attachment]));
        when(
          () => writer.removeMedia('media-1'),
        ).thenAnswer((_) async => const Right(null));
        final cubit = buildCubit(ownerId: 'apiary-1', images: ['media-1']);
        await cubit.load();

        await cubit.remove('media-1');

        expect((cubit.state as MediaGalleryLoaded).items, isEmpty);
        verify(() => writer.removeMedia('media-1')).called(1);
        await cubit.close();
      },
    );

    test('retry() on a failed item re-attempts the upload', () async {
      stubPick();
      stubAttach(
        Left(ServerFailure(code: 'file_too_large', message: 'too big')),
      );
      final cubit = buildCubit(ownerId: 'apiary-1');
      await cubit.pickFromGallery();
      final localId = (cubit.state as MediaGalleryLoaded).items.single.localId;
      expect(
        (cubit.state as MediaGalleryLoaded).items.single.status,
        MediaGalleryItemStatus.failed,
      );

      stubAttach(Right(attachment));
      await cubit.retry(localId);

      expect(
        (cubit.state as MediaGalleryLoaded).items.single.status,
        MediaGalleryItemStatus.synced,
      );
      await cubit.close();
    });

    test(
      'remove() on a synced item shows a removing status while the request is in flight',
      () async {
        when(
          () => reader.getMedia(ids: any(named: 'ids')),
        ).thenAnswer((_) async => Right([attachment]));
        final removeCompleter = Completer<Either<Failure, void>>();
        when(
          () => writer.removeMedia('media-1'),
        ).thenAnswer((_) => removeCompleter.future);
        final cubit = buildCubit(ownerId: 'apiary-1', images: ['media-1']);
        await cubit.load();

        final removeFuture = cubit.remove('media-1');
        await Future<void>.delayed(Duration.zero);
        expect(
          (cubit.state as MediaGalleryLoaded).items.single.status,
          MediaGalleryItemStatus.removing,
        );

        removeCompleter.complete(const Right(null));
        await removeFuture;
        expect((cubit.state as MediaGalleryLoaded).items, isEmpty);
        await cubit.close();
      },
    );
  });

  group('deferred mode (deferChangesUntilCommit — the edit form)', () {
    test(
      'a pick stages locally without calling attachMedia even though ownerId is already known',
      () async {
        stubPick();
        final cubit = buildCubit(ownerId: 'apiary-1');
        cubit.deferChangesUntilCommit();

        await cubit.pickFromGallery();

        final state = cubit.state as MediaGalleryLoaded;
        expect(state.items.single.status, MediaGalleryItemStatus.staged);
        expect(cubit.hasStagedPhotos, isTrue);
        expect(cubit.hasPendingChanges, isTrue);
        verifyNever(
          () => writer.attachMedia(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            localFilePath: any(named: 'localFilePath'),
            originalFilename: any(named: 'originalFilename'),
            contentType: any(named: 'contentType'),
            onProgress: any(named: 'onProgress'),
          ),
        );
        await cubit.close();
      },
    );

    test(
      'removing an already-attached photo hides it immediately without calling removeMedia',
      () async {
        when(
          () => reader.getMedia(ids: any(named: 'ids')),
        ).thenAnswer((_) async => Right([attachment]));
        final cubit = buildCubit(ownerId: 'apiary-1', images: ['media-1']);
        cubit.deferChangesUntilCommit();
        await cubit.load();

        await cubit.remove('media-1');

        expect((cubit.state as MediaGalleryLoaded).items, isEmpty);
        expect(cubit.hasPendingChanges, isTrue);
        verifyNever(() => writer.removeMedia(any()));
        await cubit.close();
      },
    );

    test(
      'removing a photo picked in this same deferred session (never uploaded) just drops it locally, same as staged mode',
      () async {
        stubPick();
        final cubit = buildCubit(ownerId: 'apiary-1');
        cubit.deferChangesUntilCommit();
        await cubit.pickFromGallery();
        final localId =
            (cubit.state as MediaGalleryLoaded).items.single.localId;

        await cubit.remove(localId);

        expect((cubit.state as MediaGalleryLoaded).items, isEmpty);
        expect(cubit.hasPendingChanges, isFalse);
        verify(() => localMediaStore.delete(any())).called(1);
        verifyNever(() => writer.removeMedia(any()));
        await cubit.close();
      },
    );

    test(
      'commitChanges uploads every staged pick and deletes every deferred removal',
      () async {
        when(
          () => reader.getMedia(ids: any(named: 'ids')),
        ).thenAnswer((_) async => Right([attachment]));
        when(
          () => writer.removeMedia('media-1'),
        ).thenAnswer((_) async => const Right(null));
        final newAttachment = MediaAttachment(
          id: 'media-2',
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          originalFilename: 'photo.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 4,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        stubPick();
        stubAttach(Right(newAttachment));
        final cubit = buildCubit(ownerId: 'apiary-1', images: ['media-1']);
        cubit.deferChangesUntilCommit();
        await cubit.load();
        await cubit.remove('media-1');
        await cubit.pickFromGallery();
        expect(cubit.hasPendingChanges, isTrue);

        await cubit.commitChanges(MediaOwnerType.apiary, 'apiary-1');

        expect(cubit.hasPendingChanges, isFalse);
        verify(() => writer.removeMedia('media-1')).called(1);
        verify(
          () => writer.attachMedia(
            ownerType: MediaOwnerType.apiary,
            ownerId: 'apiary-1',
            localFilePath: any(named: 'localFilePath'),
            originalFilename: 'photo.jpg',
            contentType: any(named: 'contentType'),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);
        final state = cubit.state as MediaGalleryLoaded;
        expect(state.items.single.status, MediaGalleryItemStatus.synced);
        await cubit.close();
      },
    );

    test(
      'a signal on ownerListChanges is a no-op while deferred, even though ownerId is already known — '
      'a reload would clobber staged picks/pending removals the user has not saved yet',
      () async {
        final controller = StreamController<void>.broadcast();
        final cubit = MediaGalleryCubit(
          reader: reader,
          writer: writer,
          localMediaStore: localMediaStore,
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          imagePicker: imagePicker,
          ownerListChanges: controller.stream,
        );
        cubit.deferChangesUntilCommit();

        controller.add(null);
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => reader.getMedia(ids: any(named: 'ids')));
        await cubit.close();
        await controller.close();
      },
    );
  });

  group('resolveDisplayPath', () {
    final serverAttachment = MediaAttachment(
      id: 'media-1',
      ownerType: MediaOwnerType.apiary,
      ownerId: 'apiary-1',
      originalFilename: 'photo.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 4,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      // No localFilePath — exactly what a `MediaAttachment` built straight
      // from a server response looks like (see `MediaResponseX.toEntity()`),
      // regardless of whether this photo was already downloaded and cached
      // once before.
    );
    final item = MediaGalleryItem(
      localId: 'media-1',
      originalFilename: 'photo.jpg',
      contentType: 'image/jpeg',
      status: MediaGalleryItemStatus.synced,
      attachment: serverAttachment,
    );

    test('a photo already sitting at its deterministic cache path is returned '
        'without any network call — this is what makes offline viewing of a '
        'previously-downloaded photo work at all', () async {
      when(
        () => localMediaStore.validExistingPath('media-1', extension: 'jpg'),
      ).thenAnswer((_) async => '/media/media-1.jpg');
      final cubit = buildCubit(ownerId: 'apiary-1');

      final path = await cubit.resolveDisplayPath(item);

      expect(path, '/media/media-1.jpg');
      verifyNever(() => reader.downloadMedia(any()));
      verify(
        () => reader.cacheDownloadedMedia('media-1', '/media/media-1.jpg'),
      ).called(1);
      await cubit.close();
    });

    test(
      'downloads, disk-caches, and remembers a photo with no local copy yet',
      () async {
        when(
          () => reader.downloadMedia('media-1'),
        ).thenAnswer((_) async => Right([1, 2, 3, 4]));
        final cubit = buildCubit(ownerId: 'apiary-1');

        final path = await cubit.resolveDisplayPath(item);

        expect(path, '/tmp/media-1.jpg');
        verify(() => reader.downloadMedia('media-1')).called(1);
        verify(
          () => localMediaStore.save(any(), id: 'media-1', extension: 'jpg'),
        ).called(1);
        verify(
          () => reader.cacheDownloadedMedia('media-1', '/tmp/media-1.jpg'),
        ).called(1);
        await cubit.close();
      },
    );

    test('two concurrent requests for the same photo share a single download — '
        'e.g. the hero preview and the gallery strip resolving the same '
        'attachment at once', () async {
      final completer = Completer<Either<Failure, List<int>>>();
      when(
        () => reader.downloadMedia('media-1'),
      ).thenAnswer((_) => completer.future);
      final cubit = buildCubit(ownerId: 'apiary-1');

      final first = cubit.resolveDisplayPath(item);
      final second = cubit.resolveDisplayPath(item);
      completer.complete(Right([1, 2, 3, 4]));
      final results = await Future.wait([first, second]);

      expect(results, ['/tmp/media-1.jpg', '/tmp/media-1.jpg']);
      verify(() => reader.downloadMedia('media-1')).called(1);
      await cubit.close();
    });

    test('retries once after a failed download before giving up', () async {
      var attempts = 0;
      when(() => reader.downloadMedia('media-1')).thenAnswer((_) async {
        attempts++;
        return attempts == 1
            ? const Left(InternalFailure(ErrorTextRaw('blip')))
            : Right([1, 2, 3, 4]);
      });
      final cubit = buildCubit(ownerId: 'apiary-1');

      final path = await cubit.resolveDisplayPath(item);

      expect(path, '/tmp/media-1.jpg');
      expect(attempts, 2);
      await cubit.close();
    });

    test('gives up (returns null, no cache write) after two consecutive '
        'failed download attempts', () async {
      when(() => reader.downloadMedia('media-1')).thenAnswer(
        (_) async => const Left(InternalFailure(ErrorTextRaw('offline'))),
      );
      final cubit = buildCubit(ownerId: 'apiary-1');

      final path = await cubit.resolveDisplayPath(item);

      expect(path, isNull);
      verify(() => reader.downloadMedia('media-1')).called(2);
      verifyNever(
        () => localMediaStore.save(
          any(),
          id: any(named: 'id'),
          extension: any(named: 'extension'),
        ),
      );
      verifyNever(() => reader.cacheDownloadedMedia(any(), any()));
      await cubit.close();
    });
  });

  group('notifyOwnerListChanged / ownerListChanges', () {
    test(
      'staging a photo does not notify — nothing changed server-side yet',
      () async {
        var notified = 0;
        stubPick();
        final cubit = MediaGalleryCubit(
          reader: reader,
          writer: writer,
          localMediaStore: localMediaStore,
          ownerType: MediaOwnerType.apiary,
          imagePicker: imagePicker,
          notifyOwnerListChanged: () => notified++,
        );

        await cubit.pickFromGallery();

        expect(notified, 0);
        await cubit.close();
      },
    );

    test('a live-mode pick notifies only once the upload actually succeeds — '
        'notifying right after staging (before the server has the file) is '
        'the exact bug this guards against: it let this cubit\'s own '
        'ownerListChanges subscription race its own in-flight upload and '
        'silently drop the completion update', () async {
      var notified = 0;
      stubPick();
      final attachCompleter = Completer<Either<Failure, MediaAttachment>>();
      when(
        () => writer.attachMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          localFilePath: any(named: 'localFilePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) => attachCompleter.future);
      final cubit = MediaGalleryCubit(
        reader: reader,
        writer: writer,
        localMediaStore: localMediaStore,
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        imagePicker: imagePicker,
        notifyOwnerListChanged: () => notified++,
      );

      final pickFuture = cubit.pickFromGallery();
      await Future<void>.delayed(Duration.zero);
      expect(notified, 0);

      attachCompleter.complete(Right(attachment));
      await pickFuture;

      expect(notified, 1);
      expect(
        (cubit.state as MediaGalleryLoaded).items.single.status,
        MediaGalleryItemStatus.synced,
      );
      await cubit.close();
    });

    test(
      'regression: wiring notify straight into this cubit\'s own '
      'ownerListChanges (as DI actually does) still ends up with the photo '
      'visible and synced — the self-triggered reload this causes must not '
      'race ahead of and clobber the upload it was itself notifying about',
      () async {
        final controller = StreamController<void>.broadcast();
        stubPick();
        stubAttach(Right(attachment));
        when(
          () => reader.getMedia(ids: any(named: 'ids')),
        ).thenAnswer((_) async => Right([attachment]));
        final cubit = MediaGalleryCubit(
          reader: reader,
          writer: writer,
          localMediaStore: localMediaStore,
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          imagePicker: imagePicker,
          notifyOwnerListChanged: () => controller.add(null),
          ownerListChanges: controller.stream,
        );

        await cubit.pickFromGallery();
        await Future<void>.delayed(Duration.zero);

        final state = cubit.state;
        expect(state, isA<MediaGalleryLoaded>());
        expect((state as MediaGalleryLoaded).items, isNotEmpty);
        expect(
          state.items.any(
            (item) => item.status == MediaGalleryItemStatus.synced,
          ),
          isTrue,
        );
        await cubit.close();
        await controller.close();
      },
    );

    test('removing a staged (local-only) photo notifies', () async {
      var notified = 0;
      stubPick();
      final cubit = MediaGalleryCubit(
        reader: reader,
        writer: writer,
        localMediaStore: localMediaStore,
        ownerType: MediaOwnerType.apiary,
        imagePicker: imagePicker,
        notifyOwnerListChanged: () => notified++,
      );
      await cubit.pickFromGallery();
      final localId = (cubit.state as MediaGalleryLoaded).items.single.localId;
      notified = 0;

      await cubit.remove(localId);

      expect(notified, 1);
      await cubit.close();
    });

    test(
      'removing a synced photo notifies only once the server call succeeds',
      () async {
        var notified = 0;
        when(
          () => reader.getMedia(ids: any(named: 'ids')),
        ).thenAnswer((_) async => Right([attachment]));
        when(
          () => writer.removeMedia('media-1'),
        ).thenAnswer((_) async => const Right(null));
        final cubit = MediaGalleryCubit(
          reader: reader,
          writer: writer,
          localMediaStore: localMediaStore,
          ownerType: MediaOwnerType.apiary,
          ownerId: 'apiary-1',
          imagePicker: imagePicker,
          notifyOwnerListChanged: () => notified++,
          resolveImages: (_) async => ['media-1'],
        );
        await cubit.load();

        await cubit.remove('media-1');

        expect(notified, 1);
        await cubit.close();
      },
    );

    test('a signal on ownerListChanges reloads a live-mode cubit', () async {
      final controller = StreamController<void>.broadcast();
      when(
        () => reader.getMedia(ids: ['media-1']),
      ).thenAnswer((_) async => Right([attachment]));
      final cubit = MediaGalleryCubit(
        reader: reader,
        writer: writer,
        localMediaStore: localMediaStore,
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
        imagePicker: imagePicker,
        ownerListChanges: controller.stream,
        resolveImages: (_) async => ['media-1'],
      );

      controller.add(null);
      await Future<void>.delayed(Duration.zero);

      verify(() => reader.getMedia(ids: ['media-1'])).called(1);
      await cubit.close();
      await controller.close();
    });

    test(
      'a signal on ownerListChanges is a no-op for a staging-mode cubit',
      () async {
        final controller = StreamController<void>.broadcast();
        final cubit = MediaGalleryCubit(
          reader: reader,
          writer: writer,
          localMediaStore: localMediaStore,
          ownerType: MediaOwnerType.apiary,
          imagePicker: imagePicker,
          ownerListChanges: controller.stream,
        );

        controller.add(null);
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => reader.getMedia(ids: any(named: 'ids')));
        await cubit.close();
        await controller.close();
      },
    );
  });

  group('closed mid-flight (owning page popped while an await is pending)', () {
    // Regression coverage for "Cannot emit new states after calling close":
    // every method below emits again after an `await`, and the widget that
    // owns this cubit (an Apiary/Hive form or details page) can be popped —
    // closing the cubit via its BlocProvider — while that await is still
    // pending. This is far more likely offline, since the offline attach
    // path (a local DB write) resolves almost immediately compared to a real
    // network round trip, making the close-before-resume race easy to hit.
    test('load() resuming after close() does not throw', () async {
      final getMediaCompleter =
          Completer<Either<Failure, List<MediaAttachment>>>();
      when(
        () => reader.getMedia(ids: any(named: 'ids')),
      ).thenAnswer((_) => getMediaCompleter.future);
      final cubit = buildCubit(ownerId: 'apiary-1', images: ['media-1']);

      final loadFuture = cubit.load();
      await cubit.close();
      getMediaCompleter.complete(Right([attachment]));

      await expectLater(loadFuture, completes);
    });

    test('a pick/attach resuming after close() does not throw', () async {
      stubPick();
      final attachCompleter = Completer<Either<Failure, MediaAttachment>>();
      when(
        () => writer.attachMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          localFilePath: any(named: 'localFilePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) => attachCompleter.future);
      final cubit = buildCubit(ownerId: 'apiary-1');

      final pickFuture = cubit.pickFromGallery();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      attachCompleter.complete(Right(attachment));

      await expectLater(pickFuture, completes);
    });

    test('remove() resuming after close() does not throw', () async {
      when(
        () => reader.getMedia(ids: any(named: 'ids')),
      ).thenAnswer((_) async => Right([attachment]));
      final removeCompleter = Completer<Either<Failure, void>>();
      when(
        () => writer.removeMedia('media-1'),
      ).thenAnswer((_) => removeCompleter.future);
      final cubit = buildCubit(ownerId: 'apiary-1', images: ['media-1']);
      await cubit.load();

      final removeFuture = cubit.remove('media-1');
      await cubit.close();
      removeCompleter.complete(const Right(null));

      await expectLater(removeFuture, completes);
    });
  });
}
