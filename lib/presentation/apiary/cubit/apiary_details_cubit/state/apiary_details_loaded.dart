part of '../apiary_details_cubit.dart';

final class ApiaryDetailsLoaded extends ApiaryDetailsState {
  const ApiaryDetailsLoaded(this.apiary, {this.hiveCount});

  @override
  final Apiary apiary;

  @override
  final int? hiveCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApiaryDetailsLoaded && other.apiary == apiary && other.hiveCount == hiveCount);

  @override
  int get hashCode => Object.hash(apiary, hiveCount);
}
