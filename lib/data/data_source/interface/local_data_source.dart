/// Persists a single cached value of type [T] on disk. A best-effort cache
/// for previously fetched data — implementations never throw, `read()`
/// returns `null` when nothing (valid) is stored.
abstract interface class LocalDataSource<T> {
  Future<T?> read();

  Future<void> write(T data);

  Future<void> clear();
}
