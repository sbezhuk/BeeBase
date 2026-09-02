import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/domain/entity/hive.dart';

extension HiveResponseX on HiveResponse {
  Hive toEntity() => Hive(
    id: id,
    apiaryId: apiaryId,
    name: name,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
    images: images,
  );
}

/// Rebuilds a full DTO from a locally-held request payload, for the offline
/// paths that need to show/reconcile an entity's fields without a server
/// round trip — [id]/[apiaryId]/[createdAt]/[updatedAt] come from wherever
/// the caller's local record of them is (a cache entry, a server response),
/// since a request payload alone carries none of them.
/// [images] has to be passed in explicitly rather than read off
/// `this.images` (a plain field edit's request never carries one - see
/// [HiveRequest.images] - so without this, rebuilding the cached response
/// here would wipe whatever images were previously known, rather than
/// leaving them alone to match the same field's server-side "omitted means
/// untouched" contract).
extension HiveRequestX on HiveRequest {
  HiveResponse toResponse({
    required String id,
    required String apiaryId,
    required DateTime createdAt,
    required DateTime updatedAt,
    List<String> images = const [],
  }) => HiveResponse(
    id: id,
    apiaryId: apiaryId,
    name: name,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
    images: images,
  );
}
