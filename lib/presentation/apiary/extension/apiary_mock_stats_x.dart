import 'package:beebase/domain/entity/apiary.dart';

/// Apiaries have no hive-count field yet — this derives a placeholder count
/// from the apiary's id so list tiles show a stable number across rebuilds
/// until the backend field lands.
extension ApiaryMockStatsX on Apiary {
  int get mockHiveCount => (id.hashCode.abs() % 12) + 1;
}
