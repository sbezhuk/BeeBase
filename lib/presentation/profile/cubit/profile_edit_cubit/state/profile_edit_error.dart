part of '../profile_edit_cubit.dart';

final class ProfileEditError extends ProfileEditState {
  const ProfileEditError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileEditError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
