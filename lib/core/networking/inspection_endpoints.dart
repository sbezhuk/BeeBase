/// Reached through `ApiEndpoints.inspections`.
///
/// Unlike [HiveEndpoints] (fully flat, no nesting at all), inspection-service
/// nests *only* its list route under the owning hive — create, get, update,
/// and delete are all flat `/api/v1/inspections` routes. The owning hive id
/// travels in the create request's body (`hive_id`, merged in by
/// `InspectionDataSource`), never in these URLs.
final class InspectionEndpoints {
  const InspectionEndpoints();

  String list(String hiveId) => '/api/v1/hives/$hiveId/inspections';
  String create() => '/api/v1/inspections';
  String byId(String id) => '/api/v1/inspections/$id';
}
