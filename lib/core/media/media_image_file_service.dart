import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// Fetches a media file on [MediaImageCacheManager]'s behalf, attaching the
/// caller's bearer token to every request.
///
/// `MediaResponse.image_url` points at media-service's authenticated
/// `GET /api/v1/media/{id}/download` — there is no public, unauthenticated
/// URL for a photo — so a plain `CachedNetworkImage` fetch would come back
/// 401. Injecting the header here (rather than passing `httpHeaders` to
/// every `CachedNetworkImage`) means the token is read *per request*, so an
/// image that loads after `AuthenticationInterceptor` refreshed the access
/// token still goes out with the current one.
final class MediaImageFileService extends FileService {
  MediaImageFileService({
    required Future<String?> Function() accessToken,
    http.Client? httpClient,
    // A private field can't be spelled as a named argument, and every
    // construction site is another library.
    // ignore: prefer_initializing_formals
  }) : _accessToken = accessToken,
       _httpClient = httpClient ?? http.Client();

  final Future<String?> Function() _accessToken;
  final http.Client _httpClient;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    if (headers != null) {
      request.headers.addAll(headers);
    }
    final token = await _accessToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return HttpGetResponse(await _httpClient.send(request));
  }
}
