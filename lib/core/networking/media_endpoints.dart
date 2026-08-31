/// `/api/v1/media*` paths. Reached through `ApiEndpoints.media`.
final class MediaEndpoints {
  const MediaEndpoints();

  String get list => '/api/v1/media';
  String byId(String id) => '/api/v1/media/$id';
  String download(String id) => '/api/v1/media/$id/download';
}
