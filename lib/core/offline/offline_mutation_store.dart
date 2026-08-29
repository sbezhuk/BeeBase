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
}
