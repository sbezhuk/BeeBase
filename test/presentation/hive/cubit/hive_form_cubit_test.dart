import 'dart:typed_data';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/presentation/hive/cubit/hive_form_cubit/hive_form_cubit.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveWriter extends Mock implements IHiveWriter {}

class MockMediaReader extends Mock implements IMediaReader {}

class MockMediaWriter extends Mock implements IMediaWriter {}

class MockLocalMediaStore extends Mock implements LocalMediaStore {}

class MockImagePicker extends Mock implements ImagePicker {}

void main() {
  const apiaryId = 'apiary-1';

  late MockHiveWriter writer;
  late HiveListRefreshNotifier refreshNotifier;
  late bool notified;

  final hive = Hive(id: 'hive-1', apiaryId: apiaryId, name: 'Hive 1', createdAt: DateTime(2026), updatedAt: DateTime(2026));

  setUpAll(() {
    registerFallbackValue(MediaOwnerType.hive);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(ImageSource.gallery);
  });

  setUp(() {
    writer = MockHiveWriter();
    refreshNotifier = HiveListRefreshNotifier();
    notified = false;
    refreshNotifier.onChanged.listen((_) => notified = true);
  });

  group('create (no initial hive)', () {
    blocTest<HiveFormCubit, HiveFormState>(
      'emits Loading then Success, calls createHive with the apiary id, and notifies the list',
      build: () {
        when(
          () => writer.createHive(
            apiaryId: apiaryId,
            name: any(named: 'name'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(hive));
        return HiveFormCubit(writer: writer, apiaryId: apiaryId, refreshNotifier: refreshNotifier);
      },
      act: (cubit) => cubit.submit(name: 'Hive 1'),
      expect: () => [const HiveFormLoading(), HiveFormSuccess(hive)],
      verify: (_) {
        verify(() => writer.createHive(apiaryId: apiaryId, name: 'Hive 1', notes: null)).called(1);
        verifyNever(
          () => writer.updateHive(
            apiaryId: any(named: 'apiaryId'),
            id: any(named: 'id'),
            name: any(named: 'name'),
          ),
        );
        expect(notified, isTrue);
      },
    );

    blocTest<HiveFormCubit, HiveFormState>(
      'emits Loading then Error on failure without notifying the list',
      build: () {
        when(
          () => writer.createHive(
            apiaryId: apiaryId,
            name: any(named: 'name'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Left(ServerFailure(code: 'name_required', message: 'name required')));
        return HiveFormCubit(writer: writer, apiaryId: apiaryId, refreshNotifier: refreshNotifier);
      },
      act: (cubit) => cubit.submit(name: ''),
      expect: () => [const HiveFormLoading(), HiveFormError(ServerFailure(code: 'name_required', message: 'name required'))],
      verify: (_) => expect(notified, isFalse),
    );
  });

  group('update (with initial hive)', () {
    blocTest<HiveFormCubit, HiveFormState>(
      'emits Loading then Success and calls updateHive with the initial id',
      build: () {
        when(
          () => writer.updateHive(
            apiaryId: apiaryId,
            id: any(named: 'id'),
            name: any(named: 'name'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(hive));
        return HiveFormCubit(writer: writer, apiaryId: apiaryId, refreshNotifier: refreshNotifier, initial: hive);
      },
      act: (cubit) => cubit.submit(name: 'Updated Name'),
      expect: () => [const HiveFormLoading(), HiveFormSuccess(hive)],
      verify: (_) {
        verify(() => writer.updateHive(apiaryId: apiaryId, id: 'hive-1', name: 'Updated Name', notes: null)).called(1);
        expect(notified, isTrue);
      },
    );
  });

  group('attaching staged photos after create', () {
    late MockMediaReader mediaReader;
    late MockMediaWriter mediaWriter;
    late MockLocalMediaStore localMediaStore;
    late MockImagePicker imagePicker;

    setUp(() {
      mediaReader = MockMediaReader();
      mediaWriter = MockMediaWriter();
      localMediaStore = MockLocalMediaStore();
      imagePicker = MockImagePicker();
      when(
        () => localMediaStore.save(
          any(),
          id: any(named: 'id'),
          extension: any(named: 'extension'),
        ),
      ).thenAnswer((_) async => '/tmp/staged.jpg');
    });

    test('flushes staged photos to the newly created hive before emitting Success', () async {
      when(
        () => imagePicker.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'photo.jpg'));
      final mediaAttachment = MediaAttachment(
        id: 'media-1',
        ownerType: MediaOwnerType.hive,
        ownerId: 'hive-1',
        originalFilename: 'photo.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 3,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => mediaWriter.attachMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          localFilePath: any(named: 'localFilePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => Right(mediaAttachment));
      final mediaGalleryCubit = MediaGalleryCubit(
        reader: mediaReader,
        writer: mediaWriter,
        localMediaStore: localMediaStore,
        ownerType: MediaOwnerType.hive,
        imagePicker: imagePicker,
      );
      await mediaGalleryCubit.pickFromGallery();
      expect(mediaGalleryCubit.hasStagedPhotos, isTrue);

      when(
        () => writer.createHive(
          apiaryId: apiaryId,
          name: any(named: 'name'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => Right(hive));
      final cubit = HiveFormCubit(writer: writer, apiaryId: apiaryId, refreshNotifier: refreshNotifier);

      await cubit.submit(name: 'Hive 1', mediaGalleryCubit: mediaGalleryCubit);

      expect(cubit.state, HiveFormSuccess(hive));
      verify(
        () => mediaWriter.attachMedia(
          ownerType: MediaOwnerType.hive,
          ownerId: hive.id,
          localFilePath: any(named: 'localFilePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      await mediaGalleryCubit.close();
    });

    test('never calls attachMedia when the gallery cubit has no staged photos', () async {
      final mediaGalleryCubit = MediaGalleryCubit(
        reader: mediaReader,
        writer: mediaWriter,
        localMediaStore: localMediaStore,
        ownerType: MediaOwnerType.hive,
        imagePicker: imagePicker,
      );
      await mediaGalleryCubit.load();

      when(
        () => writer.createHive(
          apiaryId: apiaryId,
          name: any(named: 'name'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => Right(hive));
      final cubit = HiveFormCubit(writer: writer, apiaryId: apiaryId, refreshNotifier: refreshNotifier);

      await cubit.submit(name: 'Hive 1', mediaGalleryCubit: mediaGalleryCubit);

      expect(cubit.state, HiveFormSuccess(hive));
      verifyNever(
        () => mediaWriter.attachMedia(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
          localFilePath: any(named: 'localFilePath'),
          originalFilename: any(named: 'originalFilename'),
          contentType: any(named: 'contentType'),
          onProgress: any(named: 'onProgress'),
        ),
      );
      await mediaGalleryCubit.close();
    });
  });
}
