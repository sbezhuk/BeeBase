import 'package:json_annotation/json_annotation.dart';

part 'apiary_request.g.dart';

@JsonSerializable()
final class ApiaryRequest {
  const ApiaryRequest({required this.name, this.description, this.location, this.lat, this.lon});

  factory ApiaryRequest.fromJson(Map<String, dynamic> json) => _$ApiaryRequestFromJson(json);

  final String name;
  final String? description;
  final String? location;
  final double? lat;
  final double? lon;

  Map<String, dynamic> toJson() => _$ApiaryRequestToJson(this);
}
