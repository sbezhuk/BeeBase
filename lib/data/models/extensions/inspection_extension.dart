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
