/// `/api/v1/media*` paths. Reached through `ApiEndpoints.media`.
///
/// There's deliberately no `download` path here: a photo's own
/// `MediaResponse.image_url` is the URL it's fetched from (rebuilt by the
/// server on every response), and `MediaImageCacheManager` fetches it
/// verbatim rather than reassembling it from an id.
final class MediaEndpoints {
  const MediaEndpoints();

  String get list => '/api/v1/media';
  String byId(String id) => '/api/v1/media/$id';
}
