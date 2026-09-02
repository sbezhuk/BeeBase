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

  /// Uploads a file on its own, owned only by the caller — no apiary or hive
  /// needs to exist yet, and this never attaches it to one. Returns the
  /// uploaded file's id; use [attachMedia] afterward to link it to an owner.
  Future<String> uploadMedia({
    required String filePath,
    required String originalFilename,
    required String contentType,
    String? idempotencyKey,
    void Function(int sent, int total)? onSendProgress,
  });

  /// Links an already-uploaded file (see [uploadMedia]) to an apiary or a
  /// hive the caller owns. Idempotent: calling it again with the same owner
  /// succeeds without error.
  Future<MediaResponse> attachMedia({
    required String mediaId,
    required MediaOwnerType ownerType,
    required String ownerId,
  });

  Future<List<int>> downloadMedia(String id);

  Future<void> deleteMedia(String id);
}
