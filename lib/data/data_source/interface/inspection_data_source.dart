import 'package:beebase/data/models/inspection_request.dart';
import 'package:beebase/data/models/inspection_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';

abstract interface class IInspectionDataSource {
  Future<PaginatedResponse<InspectionResponse>> getInspections(String hiveId, PageRequest request);

  Future<InspectionResponse> getInspection(String hiveId, String id);

  Future<InspectionResponse> createInspection(
    String hiveId,
    InspectionRequest request, {
    String? idempotencyKey,
  });

  Future<InspectionResponse> updateInspection(String hiveId, String id, InspectionRequest request);

  Future<void> deleteInspection(String hiveId, String id);
}
