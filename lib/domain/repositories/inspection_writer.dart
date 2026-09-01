import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/inspection_type.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IInspectionWriter {
  Future<Either<Failure, Inspection>> createInspection({
    required String hiveId,
    required DateTime date,
    required InspectionType type,
    required String notes,
  });

  Future<Either<Failure, Inspection>> updateInspection({
    required String hiveId,
    required String id,
    required DateTime date,
    required InspectionType type,
    required String notes,
  });

  Future<Either<Failure, void>> deleteInspection({required String hiveId, required String id});
}
