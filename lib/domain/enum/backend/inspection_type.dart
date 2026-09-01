import 'package:json_annotation/json_annotation.dart';

/// The category of an inspection performed on a hive — the single source of
/// truth for which inspection types exist. Adding a new type means adding a
/// value here (serialized as its SCREAMING_SNAKE_CASE wire format via
/// `@JsonEnum(fieldRename: FieldRename.screamingSnake)`) and its label under
/// `inspection.types.<name>` in `assets/langs/en-US.json` (see
/// `InspectionTypeX`); nothing else in the create/edit flow needs to change.
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum InspectionType { routine, queen, brood, health, feeding, seasonal }
