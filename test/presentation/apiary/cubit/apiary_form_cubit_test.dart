import 'dart:typed_data';

import 'package:beebase/core/location/location_service.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_form_cubit/apiary_form_cubit.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryWriter extends Mock implements IApiaryWriter {}

class MockLocationService extends Mock implements LocationService {}

class MockMediaReader extends Mock implements IMediaReader {}

class MockMediaWriter extends Mock implements IMediaWriter {}

class MockLocalMediaStore extends Mock implements LocalMediaStore {}

class MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late MockApiaryWriter writer;
  late MockLocationService locationService;
  late ApiaryListRefreshNotifier refreshNotifier;
  late bool notified;

  final apiary = Apiary(id: 'apiary-1', name: 'Back Garden', createdAt: DateTime(2026), updatedAt: DateTime(2026));

  setUpAll(() {
    registerFallbackValue(MediaOwnerType.apiary);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(ImageSource.gallery);
  });

  setUp(() {
    writer = MockApiaryWriter();
    locationService = MockLocationService();
    refreshNotifier = ApiaryListRefreshNotifier();
    notified = false;
    refreshNotifier.onChanged.listen((_) => notified = true);
  });

  group('create (no initial apiary)', () {
    blocTest<ApiaryFormCubit, ApiaryFormState>(
      'emits Loading then Success, calls createApiary, and notifies the list',
      build: () {
        when(
          () => writer.createApiary(
            name: any(named: 'name'),
            description: any(named: 'description'),
            location: any(named: 'location'),
          ),
        ).thenAnswer((_) async => Right(apiary));
        return ApiaryFormCubit(writer: writer, refreshNotifier: refreshNotifier, locationService: locationService);
      },
      act: (cubit) => cubit.submit(name: 'Back Garden'),
      expect: () => [const ApiaryFormLoading(), ApiaryFormSuccess(apiary)],
      verify: (_) {
        verify(() => writer.createApiary(name: 'Back Garden', description: null, location: null)).called(1);
        verifyNever(
          () => writer.updateApiary(
            id: any(named: 'id'),
            name: any(named: 'name'),
          ),
        );
        expect(notified, isTrue);
      },
    );

    blocTest<ApiaryFormCubit, ApiaryFormState>(
      'emits Loading then Error on failure without notifying the list',
      build: () {
        when(
          () => writer.createApiary(
            name: any(named: 'name'),
            description: any(named: 'description'),
            location: any(named: 'location'),
          ),
        ).thenAnswer((_) async => Left(ServerFailure(code: 'name_required', message: 'name required')));
        return ApiaryFormCubit(writer: writer, refreshNotifier: refreshNotifier, locationService: locationService);
      },
      act: (cubit) => cubit.submit(name: ''),
      expect: () => [const ApiaryFormLoading(), ApiaryFormError(ServerFailure(code: 'name_required', message: 'name required'))],
      verify: (_) => expect(notified, isFalse),
    );
  });

  group('update (with initial apiary)', () {
    blocTest<ApiaryFormCubit, ApiaryFormState>(
      'emits Loading then Success and calls updateApiary with the initial id',
      build: () {
        when(
          () => writer.updateApiary(
            id: any(named: 'id'),
            name: any(named: 'name'),
            description: any(named: 'description'),
            location: any(named: 'location'),
          ),
        ).thenAnswer((_) async => Right(apiary));
        return ApiaryFormCubit(
          writer: writer,
          refreshNotifier: refreshNotifier,
          locationService: locationService,
          initial: apiary,
        );
      },
      act: (cubit) => cubit.submit(name: 'Updated Name'),
      expect: () => [const ApiaryFormLoading(), ApiaryFormSuccess(apiary)],
      verify: (_) {
        verify(() => writer.updateApiary(id: 'apiary-1', name: 'Updated Name', description: null, location: null)).called(1);
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

    test('flushes staged photos to the newly created apiary before emitting Success', () async {
      when(
        () => imagePicker.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'photo.jpg'));
      final mediaAttachment = MediaAttachment(
        id: 'media-1',
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
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
        ownerType: MediaOwnerType.apiary,
        imagePicker: imagePicker,
      );
      await mediaGalleryCubit.pickFromGallery();
      expect(mediaGalleryCubit.hasStagedPhotos, isTrue);

      when(
        () => writer.createApiary(
          name: any(named: 'name'),
          description: any(named: 'description'),
          location: any(named: 'location'),
        ),
      ).thenAnswer((_) async => Right(apiary));
      final cubit = ApiaryFormCubit(writer: writer, refreshNotifier: refreshNotifier, locationService: locationService);

      await cubit.submit(name: 'Back Garden', mediaGalleryCubit: mediaGalleryCubit);

      expect(cubit.state, ApiaryFormSuccess(apiary));
      verify(
        () => mediaWriter.attachMedia(
          ownerType: MediaOwnerType.apiary,
          ownerId: apiary.id,
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
        ownerType: MediaOwnerType.apiary,
        imagePicker: imagePicker,
      );
      await mediaGalleryCubit.load();

      when(
        () => writer.createApiary(
          name: any(named: 'name'),
          description: any(named: 'description'),
          location: any(named: 'location'),
        ),
      ).thenAnswer((_) async => Right(apiary));
      final cubit = ApiaryFormCubit(writer: writer, refreshNotifier: refreshNotifier, locationService: locationService);

      await cubit.submit(name: 'Back Garden', mediaGalleryCubit: mediaGalleryCubit);

      expect(cubit.state, ApiaryFormSuccess(apiary));
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

    test('does nothing extra when no gallery cubit is passed at all', () async {
      when(
        () => writer.createApiary(
          name: any(named: 'name'),
          description: any(named: 'description'),
          location: any(named: 'location'),
        ),
      ).thenAnswer((_) async => Right(apiary));
      final cubit = ApiaryFormCubit(writer: writer, refreshNotifier: refreshNotifier, locationService: locationService);

      await cubit.submit(name: 'Back Garden');

      expect(cubit.state, ApiaryFormSuccess(apiary));
    });
  });
}
