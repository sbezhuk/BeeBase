/// Whether a [MediaAttachment] reflects the server's copy, was
/// created/queued while offline and is awaiting sync, or a sync attempt has
/// permanently failed. Mirrors [ApiarySyncStatus]/[HiveSyncStatus]'s shape —
/// the server's own `status` field (always `"available"`) is not
/// meaningfully used; this is derived locally exactly like those, by
/// cross-referencing the offline operation queue.
enum MediaSyncStatus { synced, pending, failed }
