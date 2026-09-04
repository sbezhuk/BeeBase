import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/apiary_data_source.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/extensions/apiary_extension.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

final class ApiaryRepositoryImpl extends Repository
    implements IApiaryReader, IApiaryWriter {
  ApiaryRepositoryImpl({
    required this.dataSource,
    this.localDataSource,
    this.networkInfo,
  });

  final IApiaryDataSource dataSource;
  final IApiaryLocalDataSource? localDataSource;
  final INetworkInfo? networkInfo;

  Future<bool> get _isOnline async =>
      networkInfo == null || await networkInfo!.isConnected;

  @override
  Future<Either<Failure, Page<Apiary>>> getApiaries({
    required int page,
    required int limit,
  }) {
    return on(() async {
      final online = await _isOnline;
      if (online) {
        try {
          final paginated = await dataSource.getApiaries(
            PageRequest(page: page, limit: limit),
          );
          final serverItems =
              paginated.items.map((response) => response.toEntity()).toList();

          if (localDataSource != null) {
            await localDataSource!.saveServerApiaries(serverItems);

            // Fetch all locally pending apiaries so we can:
            //   • prepend pendingCreate drafts (never reached the server yet)
            //   • replace server items with their pendingUpdate local versions
            //     (shows the correct sync badge when back online)
            //   • hide pendingDelete items (they'll be removed on next sync)
            final pending = await localDataSource!.getPendingSyncApiaries();

            // Build a lookup by serverId for server-side records with local changes.
            final pendingByServerId = <String, Apiary>{
              for (final a in pending)
                if (a.serverId != null &&
                    (a.syncStatus == SyncStatus.pendingUpdate ||
                        a.syncStatus == SyncStatus.pendingDelete))
                  a.serverId!: a,
            };

            // Substitute server items with local pending versions where needed.
            final mergedServerItems = <Apiary>[];
            for (final serverItem in serverItems) {
              final localVersion = pendingByServerId[serverItem.id] ??
                  pendingByServerId[serverItem.serverId ?? serverItem.id];
              if (localVersion == null) {
                // No local pending changes — use server version as-is.
                mergedServerItems.add(serverItem);
              } else if (localVersion.syncStatus == SyncStatus.pendingDelete) {
                // Locally deleted: hide from the list until sync confirms removal.
                continue;
              } else {
                // pendingUpdate: show the locally edited version with the badge.
                mergedServerItems.add(localVersion);
              }
            }

            if (page == 1) {
              // Prepend offline-created items (no serverId yet) in front.
              final pendingCreates =
                  pending.where((a) => a.syncStatus == SyncStatus.pendingCreate);
              return Page(
                items: [...pendingCreates, ...mergedServerItems],
                hasNext: paginated.pagination.hasNext,
              );
            }

            return Page(
              items: mergedServerItems,
              hasNext: paginated.pagination.hasNext,
            );
          }

          return Page(
            items: serverItems,
            hasNext: paginated.pagination.hasNext,
          );
        } catch (e) {
          // If remote request throws and we have local storage, fallback to local
          if (localDataSource != null) {
            final localItems = await localDataSource!.getActiveApiaries(
              page: page,
              limit: limit,
            );
            return Page(
              items: localItems,
              hasNext: localItems.length >= limit,
            );
          }
          rethrow;
        }
      }

      // Offline read
      if (localDataSource != null) {
        final localItems = await localDataSource!.getActiveApiaries(
          page: page,
          limit: limit,
        );
        return Page(
          items: localItems,
          hasNext: localItems.length >= limit,
        );
      }

      return const Page(items: [], hasNext: false);
    });
  }


  @override
  Future<Either<Failure, Apiary>> getApiary(String id) {
    return on(() async {
      final online = await _isOnline;
      if (online) {
        if (localDataSource != null) {
          final local = await localDataSource!.getApiaryById(id);
          // For locally-pending records (created or updated offline) return the
          // local version so the UI reflects the unsynchronized state, not the
          // potentially stale server version.
          if (local != null && local.syncStatus.isPending) {
            return local;
          }
        }
        try {
          final remote = (await dataSource.getApiary(id)).toEntity();
          if (localDataSource != null) {
            await localDataSource!.saveServerApiaries([remote]);
          }
          return remote;
        } catch (e) {
          if (localDataSource != null) {
            final local = await localDataSource!.getApiaryById(id);
            if (local != null) return local;
          }
          rethrow;
        }
      }

      // Offline read
      if (localDataSource != null) {
        final local = await localDataSource!.getApiaryById(id);
        if (local != null) return local;
      }
      throw const ServerException(
        statusCode: 404,
        code: 'apiary_not_found',
        message: 'Apiary not found offline',
      );
    });
  }


  @override
  Future<Either<Failure, Apiary>> createApiary({
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  }) {
    return on(() async {
      final online = await _isOnline;
      if (online) {
        final request = ApiaryRequest(
          name: name,
          description: description,
          location: location,
          lat: lat,
          lon: lon,
        );
        final created =
            (await dataSource.createApiary(request)).toEntity();
        if (localDataSource != null) {
          await localDataSource!.saveServerApiaries([created]);
        }
        return created;
      }

      // Offline create
      final now = DateTime.now();
      final localId = 'local-${now.microsecondsSinceEpoch}';
      final offlineApiary = Apiary(
        id: localId,
        localId: localId,
        name: name,
        description: description,
        location: location,
        lat: lat,
        lon: lon,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pendingCreate,
      );
      if (localDataSource != null) {
        await localDataSource!.insertApiary(offlineApiary);
      }
      return offlineApiary;
    });
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
    return on(() async {
      final online = await _isOnline;
      final existingLocal =
          localDataSource != null ? await localDataSource!.getApiaryById(id) : null;
      final isLocalOnly =
          existingLocal != null && existingLocal.syncStatus == SyncStatus.pendingCreate;

      if (online && !isLocalOnly) {
        final request = ApiaryRequest(
          name: name,
          description: description,
          location: location,
          lat: lat,
          lon: lon,
        );
        final updated =
            (await dataSource.updateApiary(id, request)).toEntity();
        if (localDataSource != null) {
          await localDataSource!.saveServerApiaries([updated]);
        }
        return updated;
      }

      // Offline or local-only update
      final now = DateTime.now();
      final newStatus = (existingLocal?.syncStatus == SyncStatus.pendingCreate)
          ? SyncStatus.pendingCreate
          : SyncStatus.pendingUpdate;

      final updatedApiary = (existingLocal ??
              Apiary(
                id: id,
                localId: id,
                name: name,
                createdAt: now,
                updatedAt: now,
              ))
          .copyWith(
        name: name,
        description: description,
        location: location,
        lat: lat,
        lon: lon,
        updatedAt: now,
        syncStatus: newStatus,
      );

      if (localDataSource != null) {
        await localDataSource!.updateApiary(updatedApiary);
      }
      return updatedApiary;
    });
  }

  @override
  Future<Either<Failure, void>> addApiaryImage({
    required String apiaryId,
    required String mediaId,
  }) {
    return on(() async {
      final online = await _isOnline;
      final existingLocal = localDataSource != null
          ? await localDataSource!.getApiaryById(apiaryId)
          : null;
      final isLocalOnly =
          existingLocal != null && existingLocal.syncStatus == SyncStatus.pendingCreate;

      if (online && !isLocalOnly) {
        final current = await dataSource.getApiary(apiaryId);
        final newImages = {
          ...current.images.map((img) => img.id),
          mediaId,
        }.toList();
        final request = ApiaryRequest(
          name: current.name,
          description: current.description,
          location: current.location,
          lat: current.lat,
          lon: current.lon,
          images: newImages,
        );
        await dataSource.updateApiary(apiaryId, request);
        if (localDataSource != null) {
          final updated = current.toEntity().copyWith(images: newImages);
          await localDataSource!.updateApiary(updated);
        }
        return;
      }

      // Offline mode
      if (localDataSource != null && existingLocal != null) {
        final newImages = {...existingLocal.images, mediaId}.toList();
        // Promote to pendingUpdate if the apiary is already synced to the server.
        // Without this, a synced apiary with offline photo attachments would never
        // enter getPendingSyncApiaries() and the photos would never be uploaded.
        final newStatus = existingLocal.syncStatus == SyncStatus.pendingCreate
            ? SyncStatus.pendingCreate  // never synced yet → keep as pendingCreate
            : SyncStatus.pendingUpdate; // synced → mark dirty so synchronizer picks it up
        final updated = existingLocal.copyWith(
          images: newImages,
          updatedAt: DateTime.now(),
          syncStatus: newStatus,
        );
        await localDataSource!.updateApiary(updated);
      }
    });
  }

  @override
  Future<Either<Failure, void>> removeApiaryImage({
    required String apiaryId,
    required String mediaId,
  }) {
    return on(() async {
      final online = await _isOnline;
      final existingLocal = localDataSource != null
          ? await localDataSource!.getApiaryById(apiaryId)
          : null;
      final isLocalOnly =
          existingLocal != null && existingLocal.syncStatus == SyncStatus.pendingCreate;

      if (online && !isLocalOnly) {
        final current = await dataSource.getApiary(apiaryId);
        if (!current.images.any((img) => img.id == mediaId)) return;
        final newImages = current.images
            .map((img) => img.id)
            .where((id) => id != mediaId)
            .toList();
        final request = ApiaryRequest(
          name: current.name,
          description: current.description,
          location: current.location,
          lat: current.lat,
          lon: current.lon,
          images: newImages,
        );
        await dataSource.updateApiary(apiaryId, request);
        if (localDataSource != null) {
          final updated = current.toEntity().copyWith(images: newImages);
          await localDataSource!.updateApiary(updated);
        }
        return;
      }

      // Offline mode
      if (localDataSource != null && existingLocal != null) {
        final isLocalOnly =
            mediaId.startsWith('local-media-') || mediaId.startsWith('staged-');
        if (!isLocalOnly) {
          throw const ServerException(
            statusCode: 400,
            code: 'cannot_delete_offline',
            message: 'Photos from online objects cannot be deleted offline',
          );
        }
        final newImages =
            existingLocal.images.where((id) => id != mediaId).toList();
        final newStatus = existingLocal.syncStatus == SyncStatus.pendingCreate
            ? SyncStatus.pendingCreate
            : SyncStatus.pendingUpdate;
        final updated = existingLocal.copyWith(
          images: newImages,
          updatedAt: DateTime.now(),
          syncStatus: newStatus,
        );
        await localDataSource!.updateApiary(updated);
      }
    });
  }


  @override
  Future<Either<Failure, void>> deleteApiary(String id) {
    return on(
      () async {
        final online = await _isOnline;
        final existingLocal = localDataSource != null
            ? await localDataSource!.getApiaryById(id)
            : null;
        final isLocalOnly =
            existingLocal != null && existingLocal.syncStatus == SyncStatus.pendingCreate;

        if (online && !isLocalOnly) {
          await dataSource.deleteApiary(id);
          if (localDataSource != null) {
            await localDataSource!.deleteApiaryPermanently(id);
          }
          return;
        }

        // Offline mode:
        if (localDataSource != null) {
          if (isLocalOnly) {
            // Created offline and never synced to server: safe to permanently remove locally
            await localDataSource!.deleteApiaryPermanently(id);
          } else {
            // Exists on backend: mark pendingDelete until successful sync
            await localDataSource!.markPendingDelete(id);
          }
        }
      },
      ignoreStatusCode: 404,
      onIgnoredStatusCode: () {},
    );
  }
}
