import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/utils/either.dart';

abstract interface class IApiaryReader {
  Future<Either<Failure, List<Apiary>>> getApiaries();

  Future<Either<Failure, Apiary>> getApiary(String id);
}
