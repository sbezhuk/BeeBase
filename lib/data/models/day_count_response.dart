import 'package:json_annotation/json_annotation.dart';

part 'day_count_response.g.dart';

@JsonSerializable()
final class DayCountResponse {
  const DayCountResponse({required this.date, required this.count});

  factory DayCountResponse.fromJson(Map<String, dynamic> json) =>
      _$DayCountResponseFromJson(json);

  final String date;
  final int count;

  Map<String, dynamic> toJson() => _$DayCountResponseToJson(this);
}
