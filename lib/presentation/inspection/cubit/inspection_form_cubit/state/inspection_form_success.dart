part of '../inspection_form_cubit.dart';

final class InspectionFormSuccess extends InspectionFormState {
  const InspectionFormSuccess(this.inspection);

  final Inspection inspection;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is InspectionFormSuccess && other.inspection == inspection);

  @override
  int get hashCode => inspection.hashCode;
}
