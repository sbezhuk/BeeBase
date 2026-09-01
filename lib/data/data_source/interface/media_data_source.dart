import 'package:beebase/data/models/media_response.dart';
import 'package:beebase/data/models/page_request.dart';
import 'package:beebase/data/models/paginated_response.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';

abstract interface class IMediaDataSource {
  Future<PaginatedResponse<MediaResponse>> listMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required PageRequest request,
  });

  Future<MediaResponse> uploadMedia({
    required MediaOwnerType ownerType,
    required String ownerId,
    required String filePath,
    required String originalFilename,
    required String contentType,
    String? idempotencyKey,
    void Function(int sent, int total)? onSendProgress,
  });

  Future<List<int>> downloadMedia(String id);

  Future<void> deleteMedia(String id);
}
