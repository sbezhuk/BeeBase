import 'package:beebase/data/models/user_response.dart';
import 'package:beebase/domain/entity/user.dart';

extension UserResponseX on UserResponse {
  User toEntity() => User(id: id, email: email, createdAt: createdAt);
}
