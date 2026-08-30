part of '../hive_form_cubit.dart';

final class HiveFormSuccess extends HiveFormState {
  const HiveFormSuccess(this.hive);

  final Hive hive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HiveFormSuccess && other.hive == hive);

  @override
  int get hashCode => hive.hashCode;
}
