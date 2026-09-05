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
  const InspectionRequest({required this.date, required this.type, required this.notes, this.images});

  factory InspectionRequest.fromJson(Map<String, dynamic> json) => _$InspectionRequestFromJson(json);

  /// Serialized as UTC — the backend parses this strictly as RFC 3339,
  /// which requires an explicit offset/`Z`; a local (non-UTC) `DateTime`'s
  /// default `toIso8601String()` omits it entirely and fails to parse.
  @JsonKey(name: 'inspected_at', toJson: _toRfc3339)
  final DateTime date;

  final InspectionType type;
  final String notes;

  /// The desired final set of already-uploaded media ids attached to this
  /// inspection. `null` (the default) leaves currently attached media
  /// untouched — [includeIfNull] omits the key entirely in that case, which
  /// is what inspection-service's `PUT` distinguishes from an explicit `[]`
  /// (detach everything). Never sent on create by the live UI flow: this
  /// client still creates first and attaches photos separately (see
  /// `InspectionRepositoryImpl.addInspectionImage`), mirroring
  /// `ApiaryRequest.images`/`HiveRequest.images` — only the offline
  /// synchronizer inlines `images` on create for inspections that already
  /// had pending local photos when they synced.
  @JsonKey(includeIfNull: false)
  final List<String>? images;

  Map<String, dynamic> toJson() => _$InspectionRequestToJson(this);
}

String _toRfc3339(DateTime date) => date.toUtc().toIso8601String();
