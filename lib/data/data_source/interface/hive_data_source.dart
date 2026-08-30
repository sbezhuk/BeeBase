import 'package:beebase/data/models/hive_request.dart';
import 'package:beebase/data/models/hive_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';

abstract interface class IHiveDataSource {
  /// No apiary filter — returns a page of the caller's hives across every
  /// apiary. See `HiveEndpoints`.
  Future<PaginatedResponse<HiveResponse>> getHives(PageRequest request);

  Future<HiveResponse> getHive(String id);

  Future<HiveResponse> createHive(
    HiveRequest request, {
    required String apiaryId,
    String? idempotencyKey,
  });

  Future<HiveResponse> updateHive(String id, HiveRequest request);

  Future<void> deleteHive(String id);
}
