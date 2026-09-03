import 'package:beebase/domain/entity/apiary_hive_count.dart';

final class ApiaryStats {
  const ApiaryStats({
    required this.totalApiaries,
    required this.apiariesWithoutHives,
    this.apiaryWithMostHives,
    required this.hiveDistribution,
  });

  final int totalApiaries;
  final int apiariesWithoutHives;
  final ApiaryHiveCount? apiaryWithMostHives;
  final List<ApiaryHiveCount> hiveDistribution;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApiaryStats &&
          other.totalApiaries == totalApiaries &&
          other.apiariesWithoutHives == apiariesWithoutHives &&
          other.apiaryWithMostHives == apiaryWithMostHives &&
          _listEquals(other.hiveDistribution, hiveDistribution));

  @override
  int get hashCode => Object.hash(
    totalApiaries,
    apiariesWithoutHives,
    apiaryWithMostHives,
    Object.hashAll(hiveDistribution),
  );
}

bool _listEquals(List<ApiaryHiveCount> a, List<ApiaryHiveCount> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
