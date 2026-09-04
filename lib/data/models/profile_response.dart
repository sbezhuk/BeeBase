import 'package:json_annotation/json_annotation.dart';

part 'profile_response.g.dart';

/// `GET`/`PUT /api/v1/profile`'s own resource — camelCase on the wire
/// (unlike every other BeeBase service) and, notably, no `createdAt`; see
/// `Profile`/`User.copyWith` for how that's reconciled.
@JsonSerializable()
final class ProfileResponse {
  const ProfileResponse({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatar,
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) => _$ProfileResponseFromJson(json);

  final String id;
  final String email;
  final String firstName;
  final String lastName;

  /// The avatar media id, or `null` if this user has no avatar set.
  final String? avatar;

  Map<String, dynamic> toJson() => _$ProfileResponseToJson(this);
}
