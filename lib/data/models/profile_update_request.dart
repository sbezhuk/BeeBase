import 'package:json_annotation/json_annotation.dart';

part 'profile_update_request.g.dart';

/// The body for `PUT /api/v1/profile`. Always carries the full desired
/// state — including [avatar] — rather than a partial patch: `avatar: null`
/// means "no avatar" (an explicit removal or one that was never set), never
/// "leave whatever's there alone".
@JsonSerializable()
final class ProfileUpdateRequest {
  const ProfileUpdateRequest({
    required this.firstName,
    required this.lastName,
    this.avatar,
  });

  factory ProfileUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$ProfileUpdateRequestFromJson(json);

  @JsonKey(name: 'first_name')
  final String firstName;

  @JsonKey(name: 'last_name')
  final String lastName;

  final String? avatar;

  Map<String, dynamic> toJson() => _$ProfileUpdateRequestToJson(this);
}
