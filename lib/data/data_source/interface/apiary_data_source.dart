import 'package:beebase/data/models/apiary_request.dart';
import 'package:beebase/data/models/apiary_response.dart';

abstract interface class IApiaryDataSource {
  Future<List<ApiaryResponse>> getApiaries();

  Future<ApiaryResponse> getApiary(String id);

  Future<ApiaryResponse> createApiary(ApiaryRequest request);

  Future<ApiaryResponse> updateApiary(String id, ApiaryRequest request);

  Future<void> deleteApiary(String id);
}
