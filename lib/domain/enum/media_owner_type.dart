/// The kind of entity a [MediaAttachment] is attached to — generic on the
/// server side (`owner_type`/`owner_id`) so the same media service can
/// support future entity types without a schema change; mobile only deals
/// with apiaries and hives today.
enum MediaOwnerType { apiary, hive }
