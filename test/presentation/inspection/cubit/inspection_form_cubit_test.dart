import 'dart:typed_data';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_form_cubit/inspection_form_cubit.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class MockInspectionWriter extends Mock implements IInspectionWriter {}

class MockMediaReader extends Mock implements IMediaReader {}

class MockMediaWriter extends Mock implements IMediaWriter {}

class MockImagePicker extends Mock implements ImagePicker {}

void main() {
  const hiveId = 'hive-1';
  final date = DateTime(2026, 1, 1);
  const type = InspectionType.queen;

  late MockInspectionWriter writer;
  late InspectionListRefreshNotifier refreshNotifier;
  late bool notified;

  final inspection = Inspection(
    id: 'inspection-1',
    hiveId: hiveId,
    date: date,
    type: type,
    notes: 'Test notes',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(InspectionType.routine);
    registerFallbackValue(MediaOwnerType.inspection);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(ImageSource.gallery);
  });

  setUp(() {
    writer = MockInspectionWriter();
    refreshNotifier = InspectionListRefreshNotifier();
    notified = false;
    refreshNotifier.onChanged.listen((_) => notified = true);
  });

  group('create (no initial inspection)', () {
    blocTest<InspectionFormCubit, InspectionFormState>(
      'emits Loading then Success, calls createInspection with the hive id, and notifies the list',
      build: () {
        when(
          () => writer.createInspection(
            hiveId: hiveId,
            date: any(named: 'date'),
            type: any(named: 'type'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(inspection));
        return InspectionFormCubit(writer: writer, hiveId: hiveId, refreshNotifier: refreshNotifier);
      },
      act: (cubit) => cubit.submit(date: date, type: type, notes: 'Test notes'),
      expect: () => [const InspectionFormLoading(), InspectionFormSuccess(inspection)],
      verify: (_) {
        verify(() => writer.createInspection(hiveId: hiveId, date: date, type: type, notes: 'Test notes')).called(1);
        verifyNever(
          () => writer.updateInspection(
            hiveId: any(named: 'hiveId'),
            id: any(named: 'id'),
            date: any(named: 'date'),
            type: any(named: 'type'),
            notes: any(named: 'notes'),
          ),
        );
        expect(notified, isTrue);
      },
    );

    blocTest<InspectionFormCubit, InspectionFormState>(
      'emits Loading then Error on failure without notifying the list',
      build: () {
        when(
          () => writer.createInspection(
            hiveId: hiveId,
            date: any(named: 'date'),
            type: any(named: 'type'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Left(ServerFailure(code: 'validation_error', message: 'invalid')));
        return InspectionFormCubit(writer: writer, hiveId: hiveId, refreshNotifier: refreshNotifier);
      },
      act: (cubit) => cubit.submit(date: date, type: type, notes: 'Test notes'),
      expect: () => [
        const InspectionFormLoading(),
        InspectionFormError(ServerFailure(code: 'validation_error', message: 'invalid')),
      ],
      verify: (_) => expect(notified, isFalse),
    );
  });

  group('update (with initial inspection)', () {
    blocTest<InspectionFormCubit, InspectionFormState>(
      'emits Loading then Success and calls updateInspection with the initial id',
      build: () {
        when(
          () => writer.updateInspection(
            hiveId: hiveId,
            id: any(named: 'id'),
            date: any(named: 'date'),
            type: any(named: 'type'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => Right(inspection));
        return InspectionFormCubit(writer: writer, hiveId: hiveId, refreshNotifier: refreshNotifier, initial: inspection);
      },
      act: (cubit) => cubit.submit(date: date, type: type, notes: 'Updated notes'),
      expect: () => [const InspectionFormLoading(), InspectionFormSuccess(inspection)],
      verify: (_) {
        verify(
          () => writer.updateInspection(hiveId: hiveId, id: 'inspection-1', date: date, type: type, notes: 'Updated notes'),
        ).called(1);
        expect(notified, isTrue);
      },
    );
  });

  group('attaching staged photos after create', () {
    late MockMediaReader mediaReader;
    late MockMediaWriter mediaWriter;
    late MockImagePicker imagePicker;

    setUp(() {
      mediaReader = MockMediaReader();
      mediaWriter = MockMediaWriter();
      imagePicker = MockImagePicker();
    });

    test('flushes staged photos to the newly created inspection before emitting Success', () async {
      when(
        () => imagePicker.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'photo.jpg'));
      final mediaAttachment = MediaAttachment(
        id: 'media-1',
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
        ownerType: MediaOwnerType.inspection,
        imagePicker: imagePicker,
      );
      await mediaGalleryCubit.pickFromGallery();
      expect(mediaGalleryCubit.hasStagedPhotos, isTrue);

      when(
        () => writer.createInspection(
          hiveId: hiveId,
          date: any(named: 'date'),
          type: any(named: 'type'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => Right(inspection));
      final cubit = InspectionFormCubit(writer: writer, hiveId: hiveId, refreshNotifier: refreshNotifier);

      await cubit.submit(date: date, type: type, notes: 'Test notes', mediaGalleryCubit: mediaGalleryCubit);

      expect(cubit.state, InspectionFormSuccess(inspection));
      verify(
        () => mediaWriter.attachMedia(
          ownerType: MediaOwnerType.inspection,
          ownerId: inspection.id,
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
        ownerType: MediaOwnerType.inspection,
        imagePicker: imagePicker,
      );
      await mediaGalleryCubit.load();

      when(
        () => writer.createInspection(
          hiveId: hiveId,
          date: any(named: 'date'),
          type: any(named: 'type'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => Right(inspection));
      final cubit = InspectionFormCubit(writer: writer, hiveId: hiveId, refreshNotifier: refreshNotifier);

      await cubit.submit(date: date, type: type, notes: 'Test notes', mediaGalleryCubit: mediaGalleryCubit);

      expect(cubit.state, InspectionFormSuccess(inspection));
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
        () => writer.createInspection(
          hiveId: hiveId,
          date: any(named: 'date'),
          type: any(named: 'type'),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => Right(inspection));
      final cubit = InspectionFormCubit(writer: writer, hiveId: hiveId, refreshNotifier: refreshNotifier);

      await cubit.submit(date: date, type: type, notes: 'Test notes');

      expect(cubit.state, InspectionFormSuccess(inspection));
    });
  });
}
