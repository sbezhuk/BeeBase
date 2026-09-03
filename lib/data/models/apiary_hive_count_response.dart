import 'package:json_annotation/json_annotation.dart';

part 'apiary_hive_count_response.g.dart';

@JsonSerializable()
final class ApiaryHiveCountResponse {
  const ApiaryHiveCountResponse({
    required this.apiaryId,
    required this.name,
    required this.hiveCount,
  });

  factory ApiaryHiveCountResponse.fromJson(Map<String, dynamic> json) =>
      _$ApiaryHiveCountResponseFromJson(json);

  @JsonKey(name: 'apiary_id')
  final String apiaryId;

  final String name;

  @JsonKey(name: 'hive_count')
  final int hiveCount;

  Map<String, dynamic> toJson() => _$ApiaryHiveCountResponseToJson(this);
}
