import 'package:beebase/core/networking/apiary_endpoints.dart';
import 'package:beebase/core/networking/auth_endpoints.dart';
import 'package:beebase/core/networking/hive_endpoints.dart';
import 'package:beebase/core/networking/inspection_endpoints.dart';
import 'package:beebase/core/networking/media_endpoints.dart';

/// Path constants for the BeeBase API, shared between data sources and the
/// networking layer (e.g. [TokenRefresher] needs the refresh path without
/// depending on the data layer). Grouped per service so a new service adds
/// its own const endpoints class here rather than growing a single flat list.
abstract final class ApiEndpoints {
  static const auth = AuthEndpoints();
  static const apiaries = ApiaryEndpoints();
  static const hives = HiveEndpoints();
  static const inspections = InspectionEndpoints();
  static const media = MediaEndpoints();
}
