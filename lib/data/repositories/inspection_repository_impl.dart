import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_local_data_source.dart';
import 'package:beebase/data/models/extensions/inspection_extension.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/domain/repositories/inspection_reader.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/domain/repositories/repository.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/pagination/page.dart';

/// An inspection's local id (see [Inspection.localId]) is always prefixed
/// this way — the exact same convention `HiveRepositoryImpl` uses — so a
/// `hiveId` still carrying that prefix means the parent hive itself hasn't
/// been assigned a server id yet ([SyncStatus.pendingCreate]), regardless of
/// the device's own connectivity.
const _localIdPrefix = 'local-';

final class InspectionRepositoryImpl extends Repository
    implements IInspectionReader, IInspectionWriter {
  InspectionRepositoryImpl({
    required this.dataSource,
    this.localDataSource,
    this.networkInfo,
  });

  final IInspectionDataSource dataSource;
  final IInspectionLocalDataSource? localDataSource;
  final INetworkInfo? networkInfo;

  Future<bool> get _isOnline async =>
      networkInfo == null || await networkInfo!.isConnected;

  @override
  Future<Either<Failure, Page<Inspection>>> getInspections({
    required String hiveId,
    required int page,
    required int limit,
  }) {
    return on(() async {
      final online = await _isOnline;
      if (online) {
        try {
          final paginated = await dataSource.getInspections(
            hiveId,
            PageRequest(page: page, limit: limit),
          );
          final serverItems = paginated.items
              .map((response) => response.toEntity())
              .toList();

          if (localDataSource != null) {
            await localDataSource!.saveServerInspections(serverItems);

            final pending = await localDataSource!
                .getPendingSyncInspectionsForHive(hiveId);

            final pendingByServerId = <String, Inspection>{
              for (final i in pending)
                if (i.serverId != null &&
                    (i.syncStatus == SyncStatus.pendingUpdate ||
                        i.syncStatus == SyncStatus.pendingDelete))
                  i.serverId!: i,
            };

            final mergedServerItems = <Inspection>[];
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

            if (page == 1) {
              final pendingCreates = pending.where(
                (i) => i.syncStatus == SyncStatus.pendingCreate,
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
            final localItems = await localDataSource!
                .getActiveInspectionsForHive(
                  hiveId: hiveId,
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
        final localItems = await localDataSource!.getActiveInspectionsForHive(
          hiveId: hiveId,
          page: page,
          limit: limit,
        );
        return Page(items: localItems, hasNext: localItems.length >= limit);
      }

      return const Page(items: [], hasNext: false);
    });
  }

  @override
  Future<Either<Failure, Inspection>> getInspection({
    required String hiveId,
    required String id,
  }) {
    return on(() async {
      final online = await _isOnline;
      if (online) {
        if (localDataSource != null) {
          final local = await localDataSource!.getInspectionById(id);
          if (local != null && local.syncStatus.isPending) {
            return local;
          }
        }
        try {
          final remote = (await dataSource.getInspection(
            hiveId,
            id,
          )).toEntity();
          if (localDataSource != null) {
            await localDataSource!.saveServerInspections([remote]);
          }
          return remote;
        } catch (e) {
          if (localDataSource != null) {
            final local = await localDataSource!.getInspectionById(id);
            if (local != null) return local;
          }
          rethrow;
        }
      }

      // Offline read
      if (localDataSource != null) {
        final local = await localDataSource!.getInspectionById(id);
        if (local != null) return local;
      }
      throw const ServerException(
        statusCode: 404,
        code: 'inspection_not_found',
        message: 'Inspection not found offline',
      );
    });
  }

  @override
  Future<Either<Failure, Inspection>> createInspection({
    required String hiveId,
    required DateTime date,
    required InspectionType type,
    required String notes,
  }) {
    return on(() async {
      final online = await _isOnline;
      final parentIsLocalOnly = hiveId.startsWith(_localIdPrefix);

      if (online && !parentIsLocalOnly) {
        final request = InspectionRequest(date: date, type: type, notes: notes);
        final created = (await dataSource.createInspection(
          hiveId,
          request,
        )).toEntity();
        if (localDataSource != null) {
          await localDataSource!.saveServerInspections([created]);
        }
        return created;
      }

      // Offline create, or the parent hive itself hasn't been assigned a
      // server id yet — either way this inspection can't be sent to the
      // backend yet (see class doc on `_localIdPrefix`).
      final now = DateTime.now();
      final localId = '$_localIdPrefix${now.microsecondsSinceEpoch}';
      final offlineInspection = Inspection(
        id: localId,
        hiveId: hiveId,
        date: date,
        type: type,
        notes: notes,
        createdAt: now,
        updatedAt: now,
        localId: localId,
        hiveLocalId: parentIsLocalOnly ? hiveId : null,
        hiveServerId: parentIsLocalOnly ? null : hiveId,
        syncStatus: SyncStatus.pendingCreate,
      );
      if (localDataSource != null) {
        await localDataSource!.insertInspection(offlineInspection);
      }
      return offlineInspection;
    });
  }

  @override
  Future<Either<Failure, Inspection>> updateInspection({
    required String hiveId,
    required String id,
    required DateTime date,
    required InspectionType type,
    required String notes,
  }) {
    return on(() async {
      final online = await _isOnline;
      final existingLocal = localDataSource != null
          ? await localDataSource!.getInspectionById(id)
          : null;
      final isLocalOnly =
          existingLocal != null &&
          existingLocal.syncStatus == SyncStatus.pendingCreate;

      if (online && !isLocalOnly) {
        final request = InspectionRequest(date: date, type: type, notes: notes);
        final updated = (await dataSource.updateInspection(
          hiveId,
          id,
          request,
        )).toEntity();
        if (localDataSource != null) {
          await localDataSource!.saveServerInspections([updated]);
        }
        return updated;
      }

      if (existingLocal == null) {
        // No cached record to fall back on and no way to know which hive
        // this inspection belongs to — refuse rather than guess.
        throw const ServerException(
          statusCode: 404,
          code: 'inspection_not_found',
          message: 'Inspection not found offline',
        );
      }

      final now = DateTime.now();
      final newStatus = existingLocal.syncStatus == SyncStatus.pendingCreate
          ? SyncStatus.pendingCreate
          : SyncStatus.pendingUpdate;

      final updatedInspection = existingLocal.copyWith(
        date: date,
        type: type,
        notes: notes,
        updatedAt: now,
        syncStatus: newStatus,
      );

      if (localDataSource != null) {
        await localDataSource!.updateInspection(updatedInspection);
      }
      return updatedInspection;
    });
  }

  /// A 404 means the server has already forgotten this inspection, so the
  /// desired end state is already true — see [on]'s `ignoreStatusCode`.
  @override
  Future<Either<Failure, void>> deleteInspection({
    required String hiveId,
    required String id,
  }) {
    return on(
      () async {
        final online = await _isOnline;
        final existingLocal = localDataSource != null
            ? await localDataSource!.getInspectionById(id)
            : null;
        final isLocalOnly =
            existingLocal != null &&
            existingLocal.syncStatus == SyncStatus.pendingCreate;

        if (online && !isLocalOnly) {
          await dataSource.deleteInspection(hiveId, id);
          if (localDataSource != null) {
            await localDataSource!.deleteInspectionPermanently(id);
          }
          return;
        }

        if (localDataSource != null) {
          if (isLocalOnly) {
            await localDataSource!.deleteInspectionPermanently(id);
          } else {
            await localDataSource!.markPendingDelete(id);
          }
        }
      },
      ignoreStatusCode: 404,
      onIgnoredStatusCode: () {},
    );
  }
}
