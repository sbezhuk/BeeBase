import 'package:json_annotation/json_annotation.dart';

part 'apiary_request.g.dart';

@JsonSerializable()
final class ApiaryRequest {
  const ApiaryRequest({required this.name, this.notes, this.location});

  factory ApiaryRequest.fromJson(Map<String, dynamic> json) => _$ApiaryRequestFromJson(json);

  final String name;
  final String? notes;
  final String? location;

  Map<String, dynamic> toJson() => _$ApiaryRequestToJson(this);
}
