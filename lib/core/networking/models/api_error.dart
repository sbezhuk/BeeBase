import 'package:json_annotation/json_annotation.dart';

part 'api_error.g.dart';

@JsonSerializable()
final class ApiError {
  const ApiError({required this.code, required this.message, this.fields});

  factory ApiError.fromJson(Map<String, dynamic> json) => _$ApiErrorFromJson(json);

  final String code;
  final String message;
  final Map<String, String>? fields;

  Map<String, dynamic> toJson() => _$ApiErrorToJson(this);
}
