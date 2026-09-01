import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'inspection_request.g.dart';

/// The body for creating/updating an inspection (`POST /api/v1/inspections`,
/// `PUT /api/v1/inspections/{id}`) — matches inspection-service's
/// `CreateRequest`/`UpdateRequest` shape. `hive_id` is only on
/// `CreateRequest`, so it's merged in separately by `InspectionDataSource`
/// rather than being a field here (mirrors `HiveRequest`).
@JsonSerializable()
final class InspectionRequest {
  const InspectionRequest({required this.date, required this.type, required this.notes});

  factory InspectionRequest.fromJson(Map<String, dynamic> json) =>
      _$InspectionRequestFromJson(json);

  /// Serialized as UTC — the backend parses this strictly as RFC 3339,
  /// which requires an explicit offset/`Z`; a local (non-UTC) `DateTime`'s
  /// default `toIso8601String()` omits it entirely and fails to parse.
  @JsonKey(name: 'inspected_at', toJson: _toRfc3339)
  final DateTime date;

  final InspectionType type;
  final String notes;

  Map<String, dynamic> toJson() => _$InspectionRequestToJson(this);
}

String _toRfc3339(DateTime date) => date.toUtc().toIso8601String();
