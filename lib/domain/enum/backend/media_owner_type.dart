import 'package:json_annotation/json_annotation.dart';

/// The kind of entity a [MediaAttachment] is attached to — generic on the
/// server side (`owner_type`/`owner_id`) so the same media service can
/// support future entity types without a schema change; mobile only deals
/// with apiaries and hives today. Serialized as its SCREAMING_SNAKE_CASE wire
/// format via `@JsonEnum(fieldRename: FieldRename.screamingSnake)`.
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum MediaOwnerType { apiary, hive }
