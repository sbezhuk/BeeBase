import 'package:json_annotation/json_annotation.dart';

part 'profile_update_request.g.dart';

/// The body for `PUT /api/v1/profile`. `firstName`/`lastName` are always
/// replaced. [avatar] is three-state, per auth-service's own contract:
/// `null` (or the field omitted) leaves the current avatar untouched, `''`
/// removes it, and an already-uploaded media-service id replaces it.
/// Fields are already camelCase on the wire — unlike every other BeeBase
/// service, auth-service's profile resource doesn't use snake_case.
@JsonSerializable()
final class ProfileUpdateRequest {
  const ProfileUpdateRequest({required this.firstName, required this.lastName, this.avatar});

  factory ProfileUpdateRequest.fromJson(Map<String, dynamic> json) => _$ProfileUpdateRequestFromJson(json);

  final String firstName;
  final String lastName;
  final String? avatar;

  Map<String, dynamic> toJson() => _$ProfileUpdateRequestToJson(this);
}
