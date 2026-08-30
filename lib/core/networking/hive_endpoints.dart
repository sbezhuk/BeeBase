/// `/api/v1/hives*` paths. Reached through `ApiEndpoints.hives`.
///
/// Flat, not nested under an apiary — hive-service's own OpenAPI spec has
/// no `/apiaries/{apiaryId}/hives` route. A hive's owning apiary travels in
/// the request body on create (`apiary_id`) and in the response
/// (`HiveResponse.apiaryId`), never in the URL. `GET /api/v1/hives` also has
/// no apiary filter — it returns a page of *all* of the caller's hives
/// across every apiary, which `HiveRepositoryImpl` filters client-side.
final class HiveEndpoints {
  const HiveEndpoints();

  String get list => '/api/v1/hives';
  String byId(String id) => '/api/v1/hives/$id';
}
