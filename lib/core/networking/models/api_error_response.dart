import 'package:beebase/core/networking/models/api_error.dart';
import 'package:json_annotation/json_annotation.dart';

part 'api_error_response.g.dart';

/// The `{"error": {"code", "message", "fields"?}}` envelope every 4xx JSON
/// error body carries, per the BeeBase API contract.
@JsonSerializable()
final class ApiErrorResponse {
  const ApiErrorResponse({required this.error});

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorResponseFromJson(json);

  final ApiError error;

  Map<String, dynamic> toJson() => _$ApiErrorResponseToJson(this);
}
