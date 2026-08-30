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
  );
}

/// Rebuilds a full DTO from a locally-held request payload, for the offline
/// paths that need to show/reconcile an entity's fields without a server
/// round trip — [id]/[apiaryId]/[createdAt]/[updatedAt] come from wherever
/// the caller's local record of them is (a cache entry, a server response),
/// since a request payload alone carries none of them.
extension HiveRequestX on HiveRequest {
  HiveResponse toResponse({
    required String id,
    required String apiaryId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => HiveResponse(
    id: id,
    apiaryId: apiaryId,
    name: name,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
