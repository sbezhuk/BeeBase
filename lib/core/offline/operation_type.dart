/// [imageAdd] links one already-uploaded media id to an Apiary/Hive by
/// fetching the owner's current record, merging the id into its `images`,
/// and PUTting it back — see `ApiaryOperationHandler`/`HiveOperationHandler`.
/// Filed under the owner's own `entityType` ('apiary'/'hive'), never
/// consolidated (see `OfflineMutationStore.saveWithConsolidatedOperation`'s
/// `matchingOperationTypes`, which existing field-edit `update` operations
/// use to make sure they never merge into — or get merged into — one of
/// these).
enum OperationType { create, update, delete, imageAdd }
