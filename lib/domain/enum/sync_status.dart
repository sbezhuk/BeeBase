enum SyncStatus {
  synced,
  pendingCreate,
  pendingUpdate,
  pendingDelete,
  syncing;

  bool get isPending =>
      this == SyncStatus.pendingCreate ||
      this == SyncStatus.pendingUpdate ||
      this == SyncStatus.pendingDelete;

  bool get isSynced => this == SyncStatus.synced;
}
