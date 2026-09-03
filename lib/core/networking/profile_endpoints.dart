/// `/api/v1/profile` — reached through `ApiEndpoints.profile`. One path,
/// shared by `GET` (read) and `PUT` (update).
final class ProfileEndpoints {
  const ProfileEndpoints();

  String get self => '/api/v1/profile';
}
