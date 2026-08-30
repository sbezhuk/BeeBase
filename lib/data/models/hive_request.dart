import 'package:json_annotation/json_annotation.dart';

part 'hive_request.g.dart';

/// The body for updating a hive (`PUT /api/v1/hives/{id}`) — matches
/// hive-service's `UpdateHiveRequest` schema exactly. Also reused for
/// create, where `apiary_id` is merged in separately by `HiveDataSource`
/// (it's on `CreateHiveRequest` but not `UpdateHiveRequest`, since a hive
/// can't be moved to a different apiary after creation).
@JsonSerializable()
final class HiveRequest {
  const HiveRequest({required this.name, this.notes});

  factory HiveRequest.fromJson(Map<String, dynamic> json) =>
      _$HiveRequestFromJson(json);

  final String name;
  final String? notes;

  Map<String, dynamic> toJson() => _$HiveRequestToJson(this);
}
