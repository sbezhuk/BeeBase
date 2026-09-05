import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/hive_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_local_data_source.dart';
import 'package:beebase/data/models/extensions/hive_extension.dart';
import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';
import 'package:beebase/utils/pagination/pagination_defaults.dart';

/// A hive's local id (see [Hive.localId]) is always prefixed this way — the
/// exact same convention `ApiaryRepositoryImpl`/offline media already use —
/// so an `apiaryId` still carrying that prefix means the parent apiary
/// itself hasn't been assigned a server id yet ([SyncStatus.pendingCreate]),
/// regardless of the device's own connectivity.
const _localIdPrefix = 'local-';

final class HiveRepositoryImpl extends Repository
    implements IHiveReader, IHiveWriter {
  HiveRepositoryImpl({
    required this.dataSource,
    this.localDataSource,
    this.inspectionLocalDataSource,
    this.networkInfo,
  });

  final IHiveDataSource dataSource;
  final IHiveLocalDataSource? localDataSource;

  /// Used only to cascade-remove a deleted hive's local inspections — see
  /// [deleteHive]. Never queried for anything else here; Inspection's own
  /// offline behavior lives entirely in `InspectionRepositoryImpl`.
  final IInspectionLocalDataSource? inspectionLocalDataSource;
  final INetworkInfo? networkInfo;

  Future<bool> get _isOnline async =>
      networkInfo == null || await networkInfo!.isConnected;

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
      final online = await _isOnline;
      if (online) {
        try {
          final paginated = await dataSource.getHives(
            PageRequest(page: page, limit: limit),
          );
          final allServerItems = paginated.items
              .map((response) => response.toEntity())
              .toList();
          final serverItems = allServerItems
              .where((hive) => hive.apiaryId == apiaryId)
              .toList();

          if (localDataSource != null) {
            await localDataSource!.saveServerHives(allServerItems);

            final pending = await localDataSource!.getPendingSyncHivesForApiary(
              apiaryId,
            );

            final pendingByServerId = <String, Hive>{
              for (final h in pending)
                if (h.serverId != null &&
                    (h.syncStatus == SyncStatus.pendingUpdate ||
                        h.syncStatus == SyncStatus.pendingDelete))
                  h.serverId!: h,
            };

            final mergedServerItems = <Hive>[];
            for (final serverItem in serverItems) {
              final localVersion = pendingByServerId[serverItem.id];
              if (localVersion == null) {
                mergedServerItems.add(serverItem);
              } else if (localVersion.syncStatus == SyncStatus.pendingDelete) {
                continue;
              } else {
                mergedServerItems.add(localVersion);
              }
            }

            if (page == PaginationDefaults.firstPage) {
              final pendingCreates = pending.where(
                (h) => h.syncStatus == SyncStatus.pendingCreate,
              );
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
          if (localDataSource != null) {
            final localItems = await localDataSource!.getActiveHivesForApiary(
              apiaryId: apiaryId,
              page: page,
              limit: limit,
            );
            return Page(items: localItems, hasNext: localItems.length >= limit);
          }
          rethrow;
        }
      }

      // Offline read
      if (localDataSource != null) {
        final localItems = await localDataSource!.getActiveHivesForApiary(
          apiaryId: apiaryId,
          page: page,
          limit: limit,
        );
        return Page(items: localItems, hasNext: localItems.length >= limit);
      }

      return const Page(items: [], hasNext: false);
    });
  }

  @override
  Future<Either<Failure, Hive>> getHive(String id) {
    return on(() async {
      final online = await _isOnline;
      if (online) {
        if (localDataSource != null) {
          final local = await localDataSource!.getHiveById(id);
          if (local != null && local.syncStatus.isPending) {
            return local;
          }
        }
        try {
          final remote = (await dataSource.getHive(id)).toEntity();
          if (localDataSource != null) {
            await localDataSource!.saveServerHives([remote]);
          }
          return remote;
        } catch (e) {
          if (localDataSource != null) {
            final local = await localDataSource!.getHiveById(id);
            if (local != null) return local;
          }
          rethrow;
        }
      }

      // Offline read
      if (localDataSource != null) {
        final local = await localDataSource!.getHiveById(id);
        if (local != null) return local;
      }
      throw const ServerException(
        statusCode: 404,
        code: 'hive_not_found',
        message: 'Hive not found offline',
      );
    });
  }

  /// Total hive count per apiary id, across every hive the caller owns.
  /// `GET /api/v1/hives` has no count of its own and no apiary filter (see
  /// [getHives]), so an accurate total means walking every page once; used
  /// by the apiary list to show each apiary's real hive count instead of a
  /// placeholder.
  @override
  Future<Either<Failure, Map<String, int>>> getHiveCounts() {
    return on(() async {
      final online = await _isOnline;
      if (online) {
        try {
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

          // Offline-created hives never reached the server yet, so they're
          // never in `all` above — add them on top, keyed by their (local)
          // apiaryId, so a freshly-created offline hive is reflected in the
          // count immediately instead of only after it syncs.
          if (localDataSource != null) {
            final pending = await localDataSource!.getPendingSyncHives();
            for (final hive in pending) {
              if (hive.syncStatus != SyncStatus.pendingCreate) continue;
              counts.update(
                hive.apiaryId,
                (value) => value + 1,
                ifAbsent: () => 1,
              );
            }
          }
          return counts;
        } catch (e) {
          if (localDataSource != null) {
            return _localHiveCounts(await localDataSource!.getAllActiveHives());
          }
          rethrow;
        }
      }

      if (localDataSource != null) {
        return _localHiveCounts(await localDataSource!.getAllActiveHives());
      }
      return <String, int>{};
    });
  }

  Map<String, int> _localHiveCounts(List<Hive> hives) {
    final counts = <String, int>{};
    for (final hive in hives) {
      counts.update(hive.apiaryId, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  @override
  Future<Either<Failure, Hive>> createHive({
    required String apiaryId,
    required String name,
    String? notes,
  }) {
    return on(() async {
      final online = await _isOnline;
      final parentIsLocalOnly = apiaryId.startsWith(_localIdPrefix);

      if (online && !parentIsLocalOnly) {
        final request = HiveRequest(name: name, notes: notes);
        final created = (await dataSource.createHive(
          request,
          apiaryId: apiaryId,
        )).toEntity();
        if (localDataSource != null) {
          await localDataSource!.saveServerHives([created]);
        }
        return created;
      }

      // Offline create, or the parent apiary itself hasn't been assigned a
      // server id yet — either way this hive can't be sent to the backend
      // yet (see class doc on `_localIdPrefix`).
      final now = DateTime.now();
      final localId = '$_localIdPrefix${now.microsecondsSinceEpoch}';
      final offlineHive = Hive(
        id: localId,
        apiaryId: apiaryId,
        name: name,
        notes: notes,
        createdAt: now,
        updatedAt: now,
        localId: localId,
        apiaryLocalId: parentIsLocalOnly ? apiaryId : null,
        apiaryServerId: parentIsLocalOnly ? null : apiaryId,
        syncStatus: SyncStatus.pendingCreate,
      );
      if (localDataSource != null) {
        await localDataSource!.insertHive(offlineHive);
      }
      return offlineHive;
    });
  }

  @override
  Future<Either<Failure, Hive>> updateHive({
    required String id,
    required String name,
    String? notes,
  }) {
    return on(() async {
      final online = await _isOnline;
      final existingLocal = localDataSource != null
          ? await localDataSource!.getHiveById(id)
          : null;
      final isLocalOnly =
          existingLocal != null &&
          existingLocal.syncStatus == SyncStatus.pendingCreate;

      if (online && !isLocalOnly) {
        final request = HiveRequest(name: name, notes: notes);
        final updated = (await dataSource.updateHive(id, request)).toEntity();
        if (localDataSource != null) {
          await localDataSource!.saveServerHives([updated]);
        }
        return updated;
      }

      if (existingLocal == null) {
        // No cached record to fall back on and no way to know which apiary
        // this hive belongs to — refuse rather than guess.
        throw const ServerException(
          statusCode: 404,
          code: 'hive_not_found',
          message: 'Hive not found offline',
        );
      }

      final now = DateTime.now();
      final newStatus = existingLocal.syncStatus == SyncStatus.pendingCreate
          ? SyncStatus.pendingCreate
          : SyncStatus.pendingUpdate;

      final updatedHive = existingLocal.copyWith(
        name: name,
        notes: notes,
        updatedAt: now,
        syncStatus: newStatus,
      );

      if (localDataSource != null) {
        await localDataSource!.updateHive(updatedHive);
      }
      return updatedHive;
    });
  }

  /// A 404 means the server has already forgotten this hive, so the desired
  /// end state is already true — see [on]'s `ignoreStatusCode`.
  @override
  Future<Either<Failure, void>> deleteHive(String id) {
    return on(
      () async {
        final online = await _isOnline;
        final existingLocal = localDataSource != null
            ? await localDataSource!.getHiveById(id)
            : null;
        final isLocalOnly =
            existingLocal != null &&
            existingLocal.syncStatus == SyncStatus.pendingCreate;

        if (online && !isLocalOnly) {
          await dataSource.deleteHive(id);
          if (localDataSource != null) {
            await localDataSource!.deleteHivePermanently(id);
          }
          return;
        }

        // Offline mode: mirror the backend's cascade delete locally and
        // immediately, regardless of whether this hive itself has synced —
        // see CLAUDE.md task spec §11-17. Only the hive's own pendingDelete
        // (the retryable half) waits for a successful sync; its inspections
        // have nothing left to retry once the hive's own DELETE succeeds,
        // since inspection-service never needs to be told about them
        // individually (the backend cascades on `DELETE /hives/{id}`).
        if (localDataSource != null) {
          await inspectionLocalDataSource?.deleteInspectionsByHiveId(id);
          if (isLocalOnly) {
            await localDataSource!.deleteHivePermanently(id);
          } else {
            await localDataSource!.markPendingDelete(id);
          }
        }
      },
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
      final online = await _isOnline;
      final existingLocal = localDataSource != null
          ? await localDataSource!.getHiveById(hiveId)
          : null;
      final isLocalOnly =
          existingLocal != null &&
          existingLocal.syncStatus == SyncStatus.pendingCreate;

      if (online && !isLocalOnly) {
        final current = await dataSource.getHive(hiveId);
        final newImages = {
          ...current.images.map((img) => img.id),
          mediaId,
        }.toList();
        final request = HiveRequest(
          name: current.name,
          notes: current.notes,
          images: newImages,
        );
        await dataSource.updateHive(hiveId, request);
        if (localDataSource != null) {
          final updated = current.toEntity().copyWith(images: newImages);
          await localDataSource!.updateHive(updated);
        }
        return;
      }

      if (localDataSource != null && existingLocal != null) {
        final newImages = {...existingLocal.images, mediaId}.toList();
        final newStatus = existingLocal.syncStatus == SyncStatus.pendingCreate
            ? SyncStatus.pendingCreate
            : SyncStatus.pendingUpdate;
        final updated = existingLocal.copyWith(
          images: newImages,
          updatedAt: DateTime.now(),
          syncStatus: newStatus,
        );
        await localDataSource!.updateHive(updated);
      }
    });
  }

  /// The reverse of [addHiveImage].
  @override
  Future<Either<Failure, void>> removeHiveImage({
    required String hiveId,
    required String mediaId,
  }) {
    return on(() async {
      final online = await _isOnline;
      final existingLocal = localDataSource != null
          ? await localDataSource!.getHiveById(hiveId)
          : null;
      final isLocalOnly =
          existingLocal != null &&
          existingLocal.syncStatus == SyncStatus.pendingCreate;

      if (online && !isLocalOnly) {
        final current = await dataSource.getHive(hiveId);
        if (!current.images.any((img) => img.id == mediaId)) return;
        final newImages = current.images
            .map((img) => img.id)
            .where((id) => id != mediaId)
            .toList();
        final request = HiveRequest(
          name: current.name,
          notes: current.notes,
          images: newImages,
        );
        await dataSource.updateHive(hiveId, request);
        if (localDataSource != null) {
          final updated = current.toEntity().copyWith(images: newImages);
          await localDataSource!.updateHive(updated);
        }
        return;
      }

      if (localDataSource != null && existingLocal != null) {
        final isMediaLocalOnly =
            mediaId.startsWith('local-media-') || mediaId.startsWith('staged-');
        if (!isMediaLocalOnly) {
          throw const ServerException(
            statusCode: 400,
            code: 'cannot_delete_offline',
            message: 'Photos from online objects cannot be deleted offline',
          );
        }
        final newImages = existingLocal.images
            .where((id) => id != mediaId)
            .toList();
        final newStatus = existingLocal.syncStatus == SyncStatus.pendingCreate
            ? SyncStatus.pendingCreate
            : SyncStatus.pendingUpdate;
        final updated = existingLocal.copyWith(
          images: newImages,
          updatedAt: DateTime.now(),
          syncStatus: newStatus,
        );
        await localDataSource!.updateHive(updated);
      }
    });
  }
}
