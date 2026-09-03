part of '../profile_edit_cubit.dart';

final class ProfileEditSuccess extends ProfileEditState {
  const ProfileEditSuccess(this.user);

  final User user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileEditSuccess && other.user == user);

  @override
  int get hashCode => user.hashCode;
}
