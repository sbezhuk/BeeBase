import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/domain/entity/apiary.dart';

extension ApiaryResponseX on ApiaryResponse {
  Apiary toEntity() => Apiary(
    id: id,
    name: name,
    description: description,
    location: location,
    lat: lat,
    lon: lon,
    createdAt: createdAt,
    updatedAt: updatedAt,
    images: images,
  );
}

/// Rebuilds a full DTO from a locally-held request payload, for the offline
/// paths that need to show/reconcile an entity's fields without a server
/// round trip — [id]/[createdAt]/[updatedAt] come from wherever the caller's
/// local record of them is (a cache entry, a server response), since a
/// request payload alone carries none of them. [images] likewise has to be
/// passed in explicitly rather than read off `this.images` (a plain field
/// edit's request never carries one - see [ApiaryRequest.images] - so
/// without this, rebuilding the cached response here would wipe whatever
/// images were previously known, rather than leaving them alone to match
/// the same field's server-side "omitted means untouched" contract).
extension ApiaryRequestX on ApiaryRequest {
  ApiaryResponse toResponse({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    List<String> images = const [],
  }) => ApiaryResponse(
    id: id,
    name: name,
    description: description,
    location: location,
    lat: lat,
    lon: lon,
    createdAt: createdAt,
    updatedAt: updatedAt,
    images: images,
  );
}
