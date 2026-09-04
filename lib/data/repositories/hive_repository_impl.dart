import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/models/extensions/hive_extension.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';
import 'package:beebase/utils/pagination/pagination_defaults.dart';

final class HiveRepositoryImpl extends Repository
    implements IHiveReader, IHiveWriter {
  HiveRepositoryImpl({required this.dataSource});

  final IHiveDataSource dataSource;

  /// `GET /api/v1/hives` has no apiary filter — it's a page of *all* of the
  /// caller's hives, so the page is filtered down to [apiaryId] here before
  /// being returned.
  @override
  Future<Either<Failure, Page<Hive>>> getHives({
    required String apiaryId,
    required int page,
    required int limit,
  }) {
    return on(() async {
      final paginated = await dataSource.getHives(
        PageRequest(page: page, limit: limit),
      );
      return Page(
        items: paginated.items
            .where((response) => response.apiaryId == apiaryId)
            .map((response) => response.toEntity())
            .toList(),
        hasNext: paginated.pagination.hasNext,
      );
    });
  }

  @override
  Future<Either<Failure, Hive>> getHive(String id) {
    return on(() async => (await dataSource.getHive(id)).toEntity());
  }

  /// Walks every page of the caller's global hive list once (there's no
  /// count endpoint and no apiary filter, see [getHives]), then tallies the
  /// result by apiary id.
  @override
  Future<Either<Failure, Map<String, int>>> getHiveCounts() {
    return on(() async {
      var page = PaginationDefaults.firstPage;
      var hasNext = true;
      final all = <HiveResponse>[];
      while (hasNext) {
        final paginated = await dataSource.getHives(
          PageRequest(page: page, limit: PaginationDefaults.defaultLimit),
        );
        all.addAll(paginated.items);
        hasNext = paginated.pagination.hasNext;
        page++;
      }
      final counts = <String, int>{};
      for (final response in all) {
        counts.update(
          response.apiaryId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      return counts;
    });
  }

  @override
  Future<Either<Failure, Hive>> createHive({
    required String apiaryId,
    required String name,
    String? notes,
  }) {
    final request = HiveRequest(name: name, notes: notes);
    return on(
      () async =>
          (await dataSource.createHive(request, apiaryId: apiaryId)).toEntity(),
    );
  }

  @override
  Future<Either<Failure, Hive>> updateHive({
    required String id,
    required String name,
    String? notes,
  }) {
    final request = HiveRequest(name: name, notes: notes);
    return on(
      () async => (await dataSource.updateHive(id, request)).toEntity(),
    );
  }

  /// A 404 means the server has already forgotten this hive, so the desired
  /// end state is already true — see [on]'s `ignoreStatusCode`.
  @override
  Future<Either<Failure, void>> deleteHive(String id) {
    return on(
      () => dataSource.deleteHive(id),
      ignoreStatusCode: 404,
      onIgnoredStatusCode: () {},
    );
  }

  /// Links [mediaId] (already uploaded to media-service, but not yet
  /// attached to anything) to [hiveId] by fetching the hive's current
  /// state, merging the id into its `images`, and PUTting it back - the
  /// only way to attach media now that media-service's own `attach`
  /// endpoint is internal-only (see `MediaRepositoryImpl.attachMedia`, the
  /// sole caller of this method via `IOwnerImageWriter`).
  @override
  Future<Either<Failure, void>> addHiveImage({
    required String hiveId,
    required String mediaId,
  }) {
    return on(() async {
      final current = await dataSource.getHive(hiveId);
      final request = HiveRequest(
        name: current.name,
        notes: current.notes,
        images: {...current.images.map((img) => img.id), mediaId}.toList(),
      );
      await dataSource.updateHive(hiveId, request);
    });
  }

  /// The reverse of [addHiveImage].
  @override
  Future<Either<Failure, void>> removeHiveImage({
    required String hiveId,
    required String mediaId,
  }) {
    return on(() async {
      final current = await dataSource.getHive(hiveId);
      if (!current.images.any((img) => img.id == mediaId)) return;
      final request = HiveRequest(
        name: current.name,
        notes: current.notes,
        images: current.images
            .map((img) => img.id)
            .where((id) => id != mediaId)
            .toList(),
      );
      await dataSource.updateHive(hiveId, request);
    });
  }
}
