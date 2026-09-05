import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_local_data_source.dart';
import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';

final class InspectionSyncResult {
  const InspectionSyncResult({
    required this.totalPending,
    required this.syncedCount,
    required this.failedCount,
    this.skippedCount = 0,
    this.errors = const [],
  });

  final int totalPending;
  final int syncedCount;
  final int failedCount;

  /// Inspections left pending because their parent hive still requires
  /// synchronization (or failed this round) — not a failure, just not yet
  /// eligible. Retried on the next sync pass.
  final int skippedCount;
  final List<String> errors;

  bool get isSuccess => failedCount == 0 && errors.isEmpty;
}

abstract interface class IInspectionSynchronizer {
  Future<InspectionSyncResult> syncInspections();
}

/// Synchronizes offline inspection changes with inspection-service, honoring
/// the strict `Hive -> Inspection` dependency: an inspection whose parent
/// hive hasn't synchronized yet (still tracked by [Inspection.hiveLocalId])
/// is left pending rather than sent to the backend — see [_resolveParent].
/// Callers must run [IHiveSynchronizer].syncHives() first on each sync pass
/// (see `DataSynchronizer`, the single entry point that guarantees this
/// ordering, itself run after apiary sync) so that a parent hive which just
/// synced is picked up in the same pass instead of requiring a second manual
/// sync. Inspections carry no media of their own — inspection-service's API
/// has no images/media field — so unlike `ApiarySynchronizer`/
/// `HiveSynchronizer` there is no media upload or orphan-media sweep here.
final class InspectionSynchronizer implements IInspectionSynchronizer {
  InspectionSynchronizer({
    required this.localDataSource,
    required this.hiveLocalDataSource,
    required this.inspectionRemoteDataSource,
    required this.networkInfo,
    this.refreshNotifier,
  });

  final IInspectionLocalDataSource localDataSource;
  final IHiveLocalDataSource hiveLocalDataSource;
  final IInspectionDataSource inspectionRemoteDataSource;
  final INetworkInfo networkInfo;
  final InspectionListRefreshNotifier? refreshNotifier;

  @override
  Future<InspectionSyncResult> syncInspections() async {
    final connected = await networkInfo.isConnected;
    if (!connected) {
      return const InspectionSyncResult(
        totalPending: 0,
        syncedCount: 0,
        failedCount: 0,
        errors: ['No internet connection'],
      );
    }

    final pending = await localDataSource.getPendingSyncInspections();

    int syncedCount = 0;
    int failedCount = 0;
    int skippedCount = 0;
    final errors = <String>[];

    for (final inspection in pending) {
      final resolved = await _resolveParent(inspection);
      if (resolved == null) {
        // Parent hive still requires sync (or failed this round) — never
        // call the Inspection API for it. It stays pending for the next
        // attempt.
        skippedCount++;
        continue;
      }

      try {
        switch (resolved.syncStatus) {
          case SyncStatus.pendingCreate:
            await _syncPendingCreate(resolved);
            syncedCount++;
            break;
          case SyncStatus.pendingUpdate:
            await _syncPendingUpdate(resolved);
            syncedCount++;
            break;
          case SyncStatus.pendingDelete:
            await _syncPendingDelete(resolved);
            syncedCount++;
            break;
          case SyncStatus.synced:
          case SyncStatus.syncing:
            break;
        }
      } catch (e) {
        failedCount++;
        errors.add(
          'Failed to sync inspection ${resolved.id} (hive ${resolved.hiveId}): $e',
        );
        // Do NOT modify or delete SQLite record! Keep it pending for retry.
      }
    }

    if (syncedCount > 0) {
      refreshNotifier?.notify();
    }

    return InspectionSyncResult(
      totalPending: pending.length,
      syncedCount: syncedCount,
      failedCount: failedCount,
      skippedCount: skippedCount,
      errors: errors,
    );
  }

  /// Returns [inspection] with its `hiveServerId` resolved and ready to
  /// sync, or `null` if the parent hive isn't there yet — enforcing the
  /// `Hive -> Inspection` ordering regardless of what order [pending] lists
  /// inspections and hives in.
  Future<Inspection?> _resolveParent(Inspection inspection) async {
    final hiveLocalId = inspection.hiveLocalId;
    if (hiveLocalId == null) {
      // Already tracking a real server hive id — nothing to resolve.
      return inspection;
    }

    final parentHive = await hiveLocalDataSource.getHiveById(hiveLocalId);
    if (parentHive == null ||
        parentHive.syncStatus != SyncStatus.synced ||
        parentHive.serverId == null) {
      // Parent still pendingCreate/pendingUpdate/pendingDelete, or its own
      // sync failed this round — this inspection must wait.
      return null;
    }

    // Parent just resolved to a server id — persist it on every inspection
    // still tracking that local hive (not just this one) so a sibling
    // created under the same offline hive resolves in the same pass too.
    await localDataSource.resolveHiveServerId(
      hiveLocalId: hiveLocalId,
      hiveServerId: parentHive.serverId!,
    );

    return inspection.copyWith(
      hiveId: parentHive.serverId,
      hiveServerId: parentHive.serverId,
    );
  }

  Future<void> _syncPendingCreate(Inspection inspection) async {
    final hiveServerId = inspection.hiveServerId;
    if (hiveServerId == null) {
      // Should be unreachable: `_resolveParent` only returns an inspection
      // once its parent has a server id.
      throw StateError(
        'Cannot sync inspection ${inspection.id}: parent hive has no server id yet',
      );
    }
    final localId = inspection.localId ?? inspection.id;

    final request = InspectionRequest(
      date: inspection.date,
      type: inspection.type,
      notes: inspection.notes,
    );
    final response = await inspectionRemoteDataSource.createInspection(
      hiveServerId,
      request,
    );

    await localDataSource.markSynced(localId: localId, serverId: response.id);
  }

  Future<void> _syncPendingUpdate(Inspection inspection) async {
    final serverId = inspection.serverId ?? inspection.id;
    final hiveServerId = inspection.hiveServerId ?? inspection.hiveId;
    final localId = inspection.localId ?? inspection.id;

    final request = InspectionRequest(
      date: inspection.date,
      type: inspection.type,
      notes: inspection.notes,
    );
    final response = await inspectionRemoteDataSource.updateInspection(
      hiveServerId,
      serverId,
      request,
    );

    await localDataSource.markSynced(localId: localId, serverId: response.id);
  }

  Future<void> _syncPendingDelete(Inspection inspection) async {
    final serverId = inspection.serverId;
    if (serverId != null && serverId.isNotEmpty) {
      try {
        await inspectionRemoteDataSource.deleteInspection(
          inspection.hiveServerId ?? inspection.hiveId,
          serverId,
        );
      } on ServerException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
    }
    await localDataSource.deleteInspectionPermanently(
      inspection.localId ?? inspection.id,
    );
  }
}
