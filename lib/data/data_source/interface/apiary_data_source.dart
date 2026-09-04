import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';

abstract interface class IApiaryDataSource {
  Future<PaginatedResponse<ApiaryResponse>> getApiaries(PageRequest request);

  Future<ApiaryResponse> getApiary(String id);

  Future<ApiaryResponse> createApiary(ApiaryRequest request);

  Future<ApiaryResponse> updateApiary(String id, ApiaryRequest request);

  Future<void> deleteApiary(String id);
}
