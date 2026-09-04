import 'package:json_annotation/json_annotation.dart';

part 'password_reset_request_request.g.dart';

@JsonSerializable()
final class PasswordResetRequestRequest {
  const PasswordResetRequestRequest({required this.email});

  factory PasswordResetRequestRequest.fromJson(Map<String, dynamic> json) =>
      _$PasswordResetRequestRequestFromJson(json);

  final String email;

  Map<String, dynamic> toJson() => _$PasswordResetRequestRequestToJson(this);
}
