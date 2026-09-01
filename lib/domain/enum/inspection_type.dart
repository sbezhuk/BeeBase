import 'package:json_annotation/json_annotation.dart';

/// The category of an inspection performed on a hive — the single source of
/// truth for which inspection types exist. Adding a new type means adding a
/// value here (with its `@JsonValue`, matching the backend's UPPER_SNAKE_CASE
/// wire format) and its label under `inspection.types.<name>` in
/// `assets/langs/en-US.json` (see `InspectionTypeX`); nothing else in the
/// create/edit flow needs to change.
enum InspectionType {
  @JsonValue('ROUTINE')
  routine,
  @JsonValue('QUEEN')
  queen,
  @JsonValue('BROOD')
  brood,
  @JsonValue('HEALTH')
  health,
  @JsonValue('FEEDING')
  feeding,
  @JsonValue('SEASONAL')
  seasonal,
}
