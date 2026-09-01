import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/domain/entity/inspection.dart';

extension InspectionResponseX on InspectionResponse {
  Inspection toEntity() => Inspection(
    id: id,
    hiveId: hiveId,
    date: date,
    type: type,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// Rebuilds a full DTO from a locally-held request payload, for the offline
/// paths that need to show/reconcile an entity's fields without a server
/// round trip — [id]/[hiveId]/[createdAt]/[updatedAt] come from wherever the
/// caller's local record of them is (a cache entry, a server response),
/// since a request payload alone carries none of them.
extension InspectionRequestX on InspectionRequest {
  InspectionResponse toResponse({
    required String id,
    required String hiveId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => InspectionResponse(
    id: id,
    hiveId: hiveId,
    date: date,
    type: type,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
