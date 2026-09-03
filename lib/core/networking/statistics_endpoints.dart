/// `/api/v1/statistics*` paths. Reached through `ApiEndpoints.statistics`.
final class StatisticsEndpoints {
  const StatisticsEndpoints();

  String get overview => '/api/v1/statistics/overview';
  String get apiaries => '/api/v1/statistics/apiaries';
  String get inspections => '/api/v1/statistics/inspections';
  String get activity => '/api/v1/statistics/activity';
}
