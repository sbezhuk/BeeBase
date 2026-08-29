import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/offline/offline_mutation_store.dart';
import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_queue.dart';
import 'package:beebase/core/offline/operation_status.dart';
import 'package:beebase/core/offline/operation_type.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/local_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/extensions/apiary_extension.dart';
import 'package:beebase/data/repositories/apiary_cache_merger.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/apiary_sync_status.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';

const _apiaryEntityType = 'apiary';

/// Cache key both this repository and its DI registration of
/// `LocalDataSource<List<ApiaryResponse>>` agree on.
const apiaryCacheKey = 'cached_apiaries';

final class ApiaryRepositoryImpl extends Repository implements IApiaryReader, IApiaryWriter {
  ApiaryRepositoryImpl({
    required this.dataSource,
    required this.localDataSource,
    required this.connectivity,
    required this.operationQueue,
    required this.offlineMutationStore,
    this.cacheMerger = const ApiaryCacheMerger(),
  });

  final IApiaryDataSource dataSource;
  final LocalDataSource<List<ApiaryResponse>> localDataSource;
  final IConnectivityService connectivity;
  final OperationQueue operationQueue;
  final OfflineMutationStore offlineMutationStore;
  final ApiaryCacheMerger cacheMerger;

  /// Network-first with a cache fallback: the repository is the only place
  /// that decides whether the list comes from the API or from the last
  /// synchronized copy — feature code always just sees a [List<Apiary>].
  @override
  Future<Either<Failure, List<Apiary>>> getApiaries() async {
    final pendingOps = await _apiaryOperations();
    if (!await connectivity.isOnline) {
      return _cachedApiariesOrFailure(const InternalFailure(ErrorTextKey('core.errors.unexpectedNetworkError')), pendingOps);
    }

    final result = await on(() async {
      final responses = await dataSource.getApiaries();
      late List<ApiaryResponse> merged;
      await localDataSource.modify((current) {
        merged = cacheMerger.mergeWithPending(responses, current ?? const [], pendingOps);
        return merged;
      });
      return merged;
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _cachedApiariesOrFailure(failure, pendingOps);
    }, (merged) => Future.value(Right(cacheMerger.toEntities(merged, pendingOps))));
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
  }) async {
    if (!await connectivity.isOnline) {
      return _createOffline(name: name, description: description, location: location, lat: lat, lon: lon);
    }

    final request = ApiaryRequest(name: name, description: description, location: location, lat: lat, lon: lon);
    final result = await on(() async {
      final response = await dataSource.createApiary(request);
      await localDataSource.modify((current) => [...(current ?? const []), response]);
      return response;
    });

    return result.fold((failure) async {
      if (failure is ServerFailure) {
        return Left(failure);
      }
      return _createOffline(name: name, description: description, location: location, lat: lat, lon: lon);
    }, (response) => Future.value(Right(response.toEntity())));
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
    if (LocalIdGenerator.isLocal(id)) {
      return Future.value(const Left(InternalFailure(ErrorTextKey('core.errors.pendingSync'))));
    }
    return on(() async {
      final request = ApiaryRequest(name: name, description: description, location: location, lat: lat, lon: lon);
      return (await dataSource.updateApiary(id, request)).toEntity();
    });
  }

  @override
  Future<Either<Failure, void>> deleteApiary(String id) {
    if (LocalIdGenerator.isLocal(id)) {
      return Future.value(const Left(InternalFailure(ErrorTextKey('core.errors.pendingSync'))));
    }
    return on(() => dataSource.deleteApiary(id));
  }

  /// Saves the local placeholder and enqueues its sync operation atomically
  /// (see [OfflineMutationStore]) — never local-entity-without-operation or
  /// the reverse.
  Future<Either<Failure, Apiary>> _createOffline({
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  }) async {
    final now = DateTime.now();
    final localId = LocalIdGenerator.generate();
    final placeholder = ApiaryResponse(
      id: localId,
      name: name,
      description: description,
      location: location,
      lat: lat,
      lon: lon,
      createdAt: now,
      updatedAt: now,
    );
    await offlineMutationStore.saveWithPendingOperation<List<ApiaryResponse>>(
      cacheKey: apiaryCacheKey,
      mutate: (current) => [...(current ?? const []), placeholder],
      toJson: (list) => list.map((response) => response.toJson()).toList(),
      fromJson: (json) => (json as List<dynamic>).map((item) => ApiaryResponse.fromJson(item as Map<String, dynamic>)).toList(),
      operation: OfflineOperation(
        id: LocalIdGenerator.generate(),
        entityType: _apiaryEntityType,
        operationType: OperationType.create,
        payload: ApiaryRequest(name: name, description: description, location: location, lat: lat, lon: lon).toJson(),
        status: OperationStatus.pending,
        createdAt: now,
        updatedAt: now,
        localEntityId: localId,
      ),
    );
    return Right(placeholder.toEntity().copyWith(syncStatus: ApiarySyncStatus.pending));
  }

  Future<List<OfflineOperation>> _apiaryOperations() async {
    return (await operationQueue.all()).where((operation) => operation.entityType == _apiaryEntityType).toList();
  }

  Future<Either<Failure, List<Apiary>>> _cachedApiariesOrFailure(Failure failure, List<OfflineOperation> pendingOps) async {
    final cached = await localDataSource.read();
    if (cached == null || cached.isEmpty) {
      return Left(failure);
    }
    return Right(cacheMerger.toEntities(cached, pendingOps));
  }
}
