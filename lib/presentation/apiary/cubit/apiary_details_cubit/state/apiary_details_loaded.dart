part of '../apiary_details_cubit.dart';

final class ApiaryDetailsLoaded extends ApiaryDetailsState {
  const ApiaryDetailsLoaded(this.apiary);

  @override
  final Apiary apiary;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is ApiaryDetailsLoaded && other.apiary == apiary);

  @override
  int get hashCode => apiary.hashCode;
}
