import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/extensions/apiary_extension.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';

final class ApiaryRepositoryImpl extends Repository implements IApiaryReader, IApiaryWriter {
  ApiaryRepositoryImpl({required this.dataSource});

  final IApiaryDataSource dataSource;

  @override
  Future<Either<Failure, List<Apiary>>> getApiaries() {
    return on(() async {
      final responses = await dataSource.getApiaries();
      return responses.map((response) => response.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, Apiary>> getApiary(String id) {
    return on(() async => (await dataSource.getApiary(id)).toEntity());
  }

  @override
  Future<Either<Failure, Apiary>> createApiary({required String name, String? description, String? location}) {
    return on(() async {
      final request = ApiaryRequest(name: name, notes: description, location: location);
      return (await dataSource.createApiary(request)).toEntity();
    });
  }

  @override
  Future<Either<Failure, Apiary>> updateApiary({
    required String id,
    required String name,
    String? description,
    String? location,
  }) {
    return on(() async {
      final request = ApiaryRequest(name: name, notes: description, location: location);
      return (await dataSource.updateApiary(id, request)).toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> deleteApiary(String id) {
    return on(() => dataSource.deleteApiary(id));
  }
}
