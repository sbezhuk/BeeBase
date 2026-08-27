part of '../apiary_form_cubit.dart';

final class ApiaryFormSuccess extends ApiaryFormState {
  const ApiaryFormSuccess(this.apiary);

  final Apiary apiary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApiaryFormSuccess && other.apiary == apiary);

  @override
  int get hashCode => apiary.hashCode;
}
