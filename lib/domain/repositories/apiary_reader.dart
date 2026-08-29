import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

abstract interface class IApiaryReader {
  Future<Either<Failure, Page<Apiary>>> getApiaries({required int page, required int limit});

  Future<Either<Failure, Apiary>> getApiary(String id);
}
