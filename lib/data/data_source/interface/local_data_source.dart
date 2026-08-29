import 'dart:async';

/// Persists a single cached value of type [T] on disk. A best-effort cache
/// for previously fetched data — implementations never throw, `read()`
/// returns `null` when nothing (valid) is stored.
abstract interface class LocalDataSource<T> {
  Future<T?> read();

  Future<void> write(T data);

  Future<void> clear();

  /// Atomic read-modify-write on this key: [update] receives the current
  /// value (`null` if nothing stored) and returns the value to persist.
  /// Implementations serialize concurrent calls so two callers modifying
  /// the same key back-to-back can't clobber one another (a plain
  /// `read()` then `write()` at the call site can't guarantee that).
  Future<void> modify(FutureOr<T> Function(T? current) update);
}
