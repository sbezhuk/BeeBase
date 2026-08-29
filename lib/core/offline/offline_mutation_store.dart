import 'package:beebase/core/offline/offline_operation.dart';

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
  /// outstanding non-synced operation for `(entityType, entityId)`, or
  /// enqueues a new one via [operation] if there isn't one yet. This is what
  /// keeps repeated offline edits to the same entity from stacking up as a
  /// growing chain of queued operations — see `ApiaryRepositoryImpl` for how
  /// [mergeInto] folds a newer payload into an existing pending `CREATE` or
  /// `UPDATE` without changing its identity.
  Future<void> saveWithConsolidatedOperation<T>({
    required String cacheKey,
    required T Function(T? current) mutate,
    required Object? Function(T value) toJson,
    required T Function(Object? json) fromJson,
    required String entityType,
    required String entityId,
    required OfflineOperation Function() operation,
    required OfflineOperation Function(OfflineOperation existing) mergeInto,
  });
}
