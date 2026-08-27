/// `/api/v1/apiaries*` paths. Reached through `ApiEndpoints.apiaries`.
final class ApiaryEndpoints {
  const ApiaryEndpoints();

  String get list => '/api/v1/apiaries';
  String byId(String id) => '/api/v1/apiaries/$id';
}
