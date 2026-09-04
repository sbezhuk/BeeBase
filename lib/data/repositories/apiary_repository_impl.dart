import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/extensions/apiary_extension.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

final class ApiaryRepositoryImpl extends Repository
    implements IApiaryReader, IApiaryWriter {
  ApiaryRepositoryImpl({required this.dataSource});

  final IApiaryDataSource dataSource;

  @override
  Future<Either<Failure, Page<Apiary>>> getApiaries({
    required int page,
    required int limit,
  }) {
    return on(() async {
      final paginated = await dataSource.getApiaries(
        PageRequest(page: page, limit: limit),
      );
      return Page(
        items: paginated.items.map((response) => response.toEntity()).toList(),
        hasNext: paginated.pagination.hasNext,
      );
    });
  }

  @override
  Future<Either<Failure, Apiary>> getApiary(String id) {
    return on(() async => (await dataSource.getApiary(id)).toEntity());
  }

  @override
  Future<Either<Failure, Apiary>> createApiary({
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  }) {
    final request = ApiaryRequest(
      name: name,
      description: description,
      location: location,
      lat: lat,
      lon: lon,
    );
    return on(
      () async => (await dataSource.createApiary(request)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, Apiary>> updateApiary({
    required String id,
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  }) {
    // images is never set here: a plain field edit never touches attached
    // media, and omitting the key (see [ApiaryRequest.images]) is exactly
    // what tells apiary-service to leave it alone. Attaching new media goes
    // through [addApiaryImage] instead.
    final request = ApiaryRequest(
      name: name,
      description: description,
      location: location,
      lat: lat,
      lon: lon,
    );
    return on(
      () async => (await dataSource.updateApiary(id, request)).toEntity(),
    );
  }

  /// Links [mediaId] (already uploaded to media-service, but not yet
  /// attached to anything) to [apiaryId] by fetching the apiary's current
  /// state, merging the id into its `images`, and PUTting it back - the
  /// only way to attach media now that media-service's own `attach`
  /// endpoint is internal-only (see `MediaRepositoryImpl.attachMedia`,
  /// the sole caller of this method via `IOwnerImageWriter`).
  @override
  Future<Either<Failure, void>> addApiaryImage({
    required String apiaryId,
    required String mediaId,
  }) {
    return on(() async {
      final current = await dataSource.getApiary(apiaryId);
      final request = ApiaryRequest(
        name: current.name,
        description: current.description,
        location: current.location,
        lat: current.lat,
        lon: current.lon,
        images: {...current.images.map((img) => img.id), mediaId}.toList(),
      );
      await dataSource.updateApiary(apiaryId, request);
    });
  }

  /// The reverse of [addApiaryImage].
  @override
  Future<Either<Failure, void>> removeApiaryImage({
    required String apiaryId,
    required String mediaId,
  }) {
    return on(() async {
      final current = await dataSource.getApiary(apiaryId);
      if (!current.images.any((img) => img.id == mediaId)) return;
      final request = ApiaryRequest(
        name: current.name,
        description: current.description,
        location: current.location,
        lat: current.lat,
        lon: current.lon,
        images: current.images
            .map((img) => img.id)
            .where((id) => id != mediaId)
            .toList(),
      );
      await dataSource.updateApiary(apiaryId, request);
    });
  }

  /// A 404 here means the server has already forgotten this entity — a
  /// delete from another device/session, say. The desired end state (no
  /// such apiary) is already true, so this is treated as a successful
  /// delete rather than a failure — otherwise a row in this state could
  /// never be removed, since every retry would 404 the same way. See [on]'s
  /// `ignoreStatusCode`.
  @override
  Future<Either<Failure, void>> deleteApiary(String id) {
    return on(
      () => dataSource.deleteApiary(id),
      ignoreStatusCode: 404,
      onIgnoredStatusCode: () {},
    );
  }
}
