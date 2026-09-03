import 'package:beebase/data/models/profile_response.dart';
import 'package:beebase/domain/entity/profile.dart';

extension ProfileResponseX on ProfileResponse {
  Profile toEntity() => Profile(
    id: id,
    email: email,
    firstName: firstName,
    lastName: lastName,
    avatarId: avatar,
    avatarLocalFilePath: avatarLocalFilePath,
  );
}
