part of '../apiary_details_cubit.dart';

sealed class ApiaryDetailsState {
  const ApiaryDetailsState();

  Apiary get apiary;

  /// This apiary's real hive count — `null` until the first fetch completes
  /// (see `ApiaryDetailsCubit.loadHiveCount`).
  int? get hiveCount;
}
