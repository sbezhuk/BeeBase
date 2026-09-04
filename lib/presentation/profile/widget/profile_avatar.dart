import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/presentation/media/widget/cached_media_image.dart';
import 'package:beebase/presentation/profile/avatar_image_resolver.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:flutter/material.dart';

/// Renders the authenticated user's avatar through the same
/// [CachedMediaImage] every other photo in the app goes through — the
/// just-picked local file while an edit is still unsaved, the cached remote
/// image otherwise, a placeholder person icon when there's neither.
///
/// The [AvatarImageResolver] round trip exists because a profile carries
/// only the avatar's media id, never its URL; it's skipped entirely while
/// [localFilePath] is set, since a not-yet-uploaded pick has no URL to
/// resolve.
final class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    required this.resolver,
    required this.avatarId,
    this.localFilePath,
    this.size = 96,
    super.key,
  });

  final AvatarImageResolver resolver;
  final String? avatarId;
  final String? localFilePath;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

final class _ProfileAvatarState extends State<ProfileAvatar> {
  late Future<String?> _imageUrlFuture = _resolve();

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarId != widget.avatarId ||
        oldWidget.localFilePath != widget.localFilePath) {
      setState(() {
        _imageUrlFuture = _resolve();
      });
    }
  }

  Future<String?> _resolve() {
    if (widget.localFilePath != null) {
      return Future.value();
    }
    return widget.resolver.resolve(widget.avatarId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FutureBuilder<String?>(
      future: _imageUrlFuture,
      builder: (context, snapshot) {
        return CachedMediaImage(
          imageUrl: snapshot.data,
          localFilePath: widget.localFilePath,
          width: widget.size,
          height: widget.size,
          borderRadius: BorderRadius.circular(widget.size / 2),
          placeholder: _placeholder(colors),
          errorWidget: _placeholder(colors),
        );
      },
    );
  }

  Widget _placeholder(AppColor colors) {
    return Container(
      width: widget.size,
      height: widget.size,
      color: colors.honey.creamLight,
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: widget.size * 0.55,
        color: colors.text.secondary,
      ),
    );
  }
}
