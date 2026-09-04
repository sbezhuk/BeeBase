import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/data/models/pagination_meta.dart';
import 'package:beebase/data/repositories/inspection_repository_impl.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInspectionDataSource extends Mock implements IInspectionDataSource {}

void main() {
  const hiveId = 'hive-1';

  late MockInspectionDataSource dataSource;
  late InspectionRepositoryImpl repository;

  final inspectionResponse = InspectionResponse(
    id: 'inspection-1',
    hiveId: hiveId,
    date: DateTime(2026, 1, 1),
    type: InspectionType.routine,
    notes: 'All looks good',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(
      InspectionRequest(date: DateTime(2026), type: InspectionType.routine, notes: 'notes'),
    );
    registerFallbackValue(const PageRequest(page: 1, limit: 20));
  });

  setUp(() {
    dataSource = MockInspectionDataSource();
    repository = InspectionRepositoryImpl(dataSource: dataSource);
  });

  group('getInspections', () {
    test('returns mapped Page<Inspection> on success', () async {
      when(() => dataSource.getInspections(hiveId, any())).thenAnswer(
        (_) async => PaginatedResponse(
          items: [inspectionResponse],
          pagination: const PaginationMeta(
            page: 1,
            limit: 20,
            total: 1,
            totalPages: 1,
            hasNext: false,
            hasPrevious: false,
          ),
        ),
      );

      final result = await repository.getInspections(hiveId: hiveId, page: 1, limit: 20);

      result.fold(
        (_) => fail('expected Right'),
        (page) {
          expect(page.items.length, 1);
          expect(page.items.first.id, 'inspection-1');
        },
      );
    });

    test('returns ServerFailure when dataSource throws', () async {
      when(() => dataSource.getInspections(hiveId, any())).thenThrow(
        const ServerException(statusCode: 500, code: 'error', message: 'failed'),
      );

      final result = await repository.getInspections(hiveId: hiveId, page: 1, limit: 20);

      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('getInspection', () {
    test('returns mapped Inspection on success', () async {
      when(() => dataSource.getInspection(hiveId, 'inspection-1')).thenAnswer(
        (_) async => inspectionResponse,
      );

      final result = await repository.getInspection(hiveId: hiveId, id: 'inspection-1');

      result.fold(
        (_) => fail('expected Right'),
        (inspection) => expect(inspection.id, 'inspection-1'),
      );
    });
  });

  group('createInspection', () {
    test('calls dataSource.createInspection and returns mapped Inspection', () async {
      when(() => dataSource.createInspection(hiveId, any())).thenAnswer(
        (_) async => inspectionResponse,
      );

      final result = await repository.createInspection(
        hiveId: hiveId,
        date: DateTime(2026, 1, 1),
        type: InspectionType.routine,
        notes: 'All looks good',
      );

      result.fold(
        (_) => fail('expected Right'),
        (inspection) => expect(inspection.id, 'inspection-1'),
      );
    });
  });

  group('updateInspection', () {
    test('calls dataSource.updateInspection and returns mapped Inspection', () async {
      when(() => dataSource.updateInspection(hiveId, 'inspection-1', any())).thenAnswer(
        (_) async => inspectionResponse,
      );

      final result = await repository.updateInspection(
        hiveId: hiveId,
        id: 'inspection-1',
        date: DateTime(2026, 1, 1),
        type: InspectionType.routine,
        notes: 'All looks good',
      );

      result.fold(
        (_) => fail('expected Right'),
        (inspection) => expect(inspection.id, 'inspection-1'),
      );
    });
  });

  group('deleteInspection', () {
    test('calls dataSource.deleteInspection', () async {
      when(() => dataSource.deleteInspection(hiveId, 'inspection-1')).thenAnswer(
        (_) async {},
      );

      final result = await repository.deleteInspection(hiveId: hiveId, id: 'inspection-1');

      expect(result.isRight, isTrue);
      verify(() => dataSource.deleteInspection(hiveId, 'inspection-1')).called(1);
    });

    test('treats 404 as successful delete', () async {
      when(() => dataSource.deleteInspection(hiveId, 'inspection-1')).thenThrow(
        const ServerException(statusCode: 404, code: 'not_found', message: 'Not found'),
      );

      final result = await repository.deleteInspection(hiveId: hiveId, id: 'inspection-1');

      expect(result.isRight, isTrue);
    });
  });
}
