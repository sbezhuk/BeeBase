import 'package:beebase/domain/repositories/media_reader.dart';

/// Resolves the `imageUrl` a `ProfileAvatar` renders from.
///
/// An avatar is the one photo the backend hands over as a bare media id:
/// auth-service's profile resource carries `avatar` (an id) and nothing
/// else, so the URL has to be looked up from media-service. That lookup
/// goes through [IMediaReader] like every other media read.
///
/// Deliberately not part of `MediaGalleryCubit`: an avatar is a single field
/// on the user, not an entry in some owner's `images` list (see
/// `ProfileRepositoryImpl`'s doc on why avatars skip `MediaOwnerType`/
/// `IOwnerImageWriter` entirely).
final class AvatarImageResolver {
  const AvatarImageResolver({required this.mediaReader});

  final IMediaReader mediaReader;

  /// `null` when there is nothing to fetch: no avatar set, or a lookup that
  /// failed. Both are normal states, not errors.
  Future<String?> resolve(String? avatarId) async {
    if (avatarId == null) {
      return null;
    }
    final result = await mediaReader.getMedia(ids: [avatarId]);
    return result.fold(
      (_) => null,
      (items) => items.isEmpty ? null : items.first.imageUrl,
    );
  }
}
