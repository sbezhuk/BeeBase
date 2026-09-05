import 'package:json_annotation/json_annotation.dart';

part 'delete_account_request.g.dart';

@JsonSerializable()
final class DeleteAccountRequest {
  const DeleteAccountRequest({required this.otp});

  factory DeleteAccountRequest.fromJson(Map<String, dynamic> json) => _$DeleteAccountRequestFromJson(json);

  final String otp;

  Map<String, dynamic> toJson() => _$DeleteAccountRequestToJson(this);
}
