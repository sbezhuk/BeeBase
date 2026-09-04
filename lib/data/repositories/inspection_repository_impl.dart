import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/models/extensions/inspection_extension.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/repositories/inspection_reader.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

final class InspectionRepositoryImpl extends Repository
    implements IInspectionReader, IInspectionWriter {
  InspectionRepositoryImpl({required this.dataSource});

  final IInspectionDataSource dataSource;

  @override
  Future<Either<Failure, Page<Inspection>>> getInspections({
    required String hiveId,
    required int page,
    required int limit,
  }) {
    return on(() async {
      final paginated = await dataSource.getInspections(
        hiveId,
        PageRequest(page: page, limit: limit),
      );
      return Page(
        items: paginated.items.map((response) => response.toEntity()).toList(),
        hasNext: paginated.pagination.hasNext,
      );
    });
  }

  @override
  Future<Either<Failure, Inspection>> getInspection({
    required String hiveId,
    required String id,
  }) {
    return on(
      () async => (await dataSource.getInspection(hiveId, id)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, Inspection>> createInspection({
    required String hiveId,
    required DateTime date,
    required InspectionType type,
    required String notes,
  }) {
    final request = InspectionRequest(date: date, type: type, notes: notes);
    return on(
      () async =>
          (await dataSource.createInspection(hiveId, request)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, Inspection>> updateInspection({
    required String hiveId,
    required String id,
    required DateTime date,
    required InspectionType type,
    required String notes,
  }) {
    final request = InspectionRequest(date: date, type: type, notes: notes);
    return on(
      () async =>
          (await dataSource.updateInspection(hiveId, id, request)).toEntity(),
    );
  }

  /// A 404 means the server has already forgotten this inspection, so the
  /// desired end state is already true — see [on]'s `ignoreStatusCode`.
  @override
  Future<Either<Failure, void>> deleteInspection({
    required String hiveId,
    required String id,
  }) {
    return on(
      () => dataSource.deleteInspection(hiveId, id),
      ignoreStatusCode: 404,
      onIgnoredStatusCode: () {},
    );
  }
}
