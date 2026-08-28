import 'package:json_annotation/json_annotation.dart';

part 'register_request.g.dart';

@JsonSerializable()
final class RegisterRequest {
  const RegisterRequest({required this.email, required this.password});

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);

  final String email;
  final String password;

  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}
