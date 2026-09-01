/// Whether an [Inspection] reflects the server's copy, was created/changed
/// while offline and is awaiting sync, or a sync attempt has permanently
/// failed.
enum InspectionSyncStatus { synced, pending, failed }
