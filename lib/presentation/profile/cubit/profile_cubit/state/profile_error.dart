part of '../profile_cubit.dart';

final class ProfileError extends ProfileState {
  const ProfileError(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileError && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
