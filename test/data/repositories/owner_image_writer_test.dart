import 'package:beebase/data/repositories/owner_image_writer.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiaryWriter extends Mock implements IApiaryWriter {}

class MockHiveWriter extends Mock implements IHiveWriter {}

class MockInspectionWriter extends Mock implements IInspectionWriter {}

void main() {
  late MockApiaryWriter apiaryWriter;
  late MockHiveWriter hiveWriter;
  late MockInspectionWriter inspectionWriter;
  late OwnerImageWriter ownerImageWriter;

  setUp(() {
    apiaryWriter = MockApiaryWriter();
    hiveWriter = MockHiveWriter();
    inspectionWriter = MockInspectionWriter();
    ownerImageWriter = OwnerImageWriter(apiaryWriter: apiaryWriter, hiveWriter: hiveWriter, inspectionWriter: inspectionWriter);
  });

  group('addImage', () {
    test('routes MediaOwnerType.inspection to addInspectionImage', () async {
      when(
        () => inspectionWriter.addInspectionImage(inspectionId: 'inspection-1', mediaId: 'media-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await ownerImageWriter.addImage(
        ownerType: MediaOwnerType.inspection,
        ownerId: 'inspection-1',
        mediaId: 'media-1',
      );

      expect(result.isRight, isTrue);
      verify(() => inspectionWriter.addInspectionImage(inspectionId: 'inspection-1', mediaId: 'media-1')).called(1);
      verifyNever(
        () => apiaryWriter.addApiaryImage(
          apiaryId: any(named: 'apiaryId'),
          mediaId: any(named: 'mediaId'),
        ),
      );
      verifyNever(
        () => hiveWriter.addHiveImage(
          hiveId: any(named: 'hiveId'),
          mediaId: any(named: 'mediaId'),
        ),
      );
    });
  });

  group('removeImage', () {
    test('routes MediaOwnerType.inspection to removeInspectionImage', () async {
      when(
        () => inspectionWriter.removeInspectionImage(inspectionId: 'inspection-1', mediaId: 'media-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await ownerImageWriter.removeImage(
        ownerType: MediaOwnerType.inspection,
        ownerId: 'inspection-1',
        mediaId: 'media-1',
      );

      expect(result.isRight, isTrue);
      verify(() => inspectionWriter.removeInspectionImage(inspectionId: 'inspection-1', mediaId: 'media-1')).called(1);
      verifyNever(
        () => apiaryWriter.removeApiaryImage(
          apiaryId: any(named: 'apiaryId'),
          mediaId: any(named: 'mediaId'),
        ),
      );
      verifyNever(
        () => hiveWriter.removeHiveImage(
          hiveId: any(named: 'hiveId'),
          mediaId: any(named: 'mediaId'),
        ),
      );
    });
  });
}
