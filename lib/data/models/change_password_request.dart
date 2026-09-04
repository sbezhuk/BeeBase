import 'package:json_annotation/json_annotation.dart';

part 'change_password_request.g.dart';

@JsonSerializable()
final class ChangePasswordRequest {
  const ChangePasswordRequest({required this.currentPassword, required this.newPassword, required this.otp});

  factory ChangePasswordRequest.fromJson(Map<String, dynamic> json) => _$ChangePasswordRequestFromJson(json);

  @JsonKey(name: 'current_password')
  final String currentPassword;

  @JsonKey(name: 'new_password')
  final String newPassword;

  final String otp;

  Map<String, dynamic> toJson() => _$ChangePasswordRequestToJson(this);
}
