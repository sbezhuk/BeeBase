import 'package:beebase/data/models/activity_item_response.dart';
import 'package:json_annotation/json_annotation.dart';

part 'activity_response.g.dart';

@JsonSerializable(explicitToJson: true)
final class ActivityResponse {
  const ActivityResponse({required this.items});

  factory ActivityResponse.fromJson(Map<String, dynamic> json) =>
      _$ActivityResponseFromJson(json);

  final List<ActivityItemResponse> items;

  Map<String, dynamic> toJson() => _$ActivityResponseToJson(this);
}
