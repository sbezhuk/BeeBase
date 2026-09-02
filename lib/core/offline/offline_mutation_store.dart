import 'package:beebase/core/offline/offline_operation.dart';
import 'package:beebase/core/offline/operation_type.dart';

/// Saves a cache entry and enqueues its corresponding pending operation
/// atomically — the local-first-create seam. Prevents ever ending up with
/// the entity persisted but not its sync operation, or the reverse. Entirely
/// entity-agnostic: any feature supplies its own cache key, mutator, and
/// [OfflineOperation].
abstract interface class OfflineMutationStore {
  Future<void> saveWithPendingOperation<T>({
    required String cacheKey,
    required T Function(T? current) mutate,
    required Object? Function(T value) toJson,
    required T Function(Object? json) fromJson,
    required OfflineOperation operation,
  });

  /// Updates the cached entity and folds the change into the single
  /// outstanding non-synced operation for `(entityType, entityId)` whose
  /// [OfflineOperation.operationType] is in [matchingOperationTypes], or
  /// enqueues a new one via [operation] if there isn't one yet. This is what
  /// keeps repeated offline edits to the same entity from stacking up as a
  /// growing chain of queued operations — see `ApiaryRepositoryImpl` for how
  /// [mergeInto] folds a newer payload into an existing pending `CREATE` or
  /// `UPDATE` without changing its identity.
  ///
  /// [matchingOperationTypes] exists because `entityType`+`entityId` alone
  /// isn't a unique key for "the operation this edit belongs to": an Apiary
  /// or Hive can also have `OperationType.imageAdd` operations queued under
  /// that same `(entityType, entityId)` pair (see
  /// `ApiaryOperationHandler`/`HiveOperationHandler`), each tied to one
  /// specific photo via its own `dependsOnOperationId` — a plain field edit
  /// (name/location/etc.) must never find and silently overwrite one of
  /// those (it would discard the photo link and orphan the dependency), so
  /// callers restrict the lookup to the operation types their own edit could
  /// actually mean.
  Future<void> saveWithConsolidatedOperation<T>({
    required String cacheKey,
    required T Function(T? current) mutate,
    required Object? Function(T value) toJson,
    required T Function(Object? json) fromJson,
    required String entityType,
    required String entityId,
    required Set<OperationType> matchingOperationTypes,
    required OfflineOperation Function() operation,
    required OfflineOperation Function(OfflineOperation existing) mergeInto,
  });
}
