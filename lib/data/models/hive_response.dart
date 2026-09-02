import 'package:json_annotation/json_annotation.dart';

part 'hive_response.g.dart';

@JsonSerializable()
final class HiveResponse {
  const HiveResponse({
    required this.id,
    required this.apiaryId,
    required this.name,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
  });

  factory HiveResponse.fromJson(Map<String, dynamic> json) =>
      _$HiveResponseFromJson(json);

  final String id;

  @JsonKey(name: 'apiary_id')
  final String apiaryId;

  final String name;
  final String? notes;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  /// Media ids currently attached to this hive — hive-service's own source
  /// of truth (a local column there), returned on every read/write response
  /// rather than queried live from media-service. Only as fresh as the last
  /// fetch. Defaults to `[]` for a response rebuilt locally from a plain
  /// field-edit request (see `HiveRequestX.toResponse`), which never carries
  /// a caller-supplied value for it.
  @JsonKey(defaultValue: <String>[])
  final List<String> images;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$HiveResponseToJson(this);
}
