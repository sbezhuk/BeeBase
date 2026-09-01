import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

abstract interface class IInspectionReader {
  Future<Either<Failure, Page<Inspection>>> getInspections({
    required String hiveId,
    required int page,
    required int limit,
  });

  Future<Either<Failure, Inspection>> getInspection({required String hiveId, required String id});
}
