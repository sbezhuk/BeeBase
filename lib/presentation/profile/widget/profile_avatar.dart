import 'dart:io';

import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/presentation/profile/avatar_path_resolver.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:flutter/material.dart';

/// Renders the authenticated user's avatar — a local file (a pending pick,
/// or a downloaded render cache — see [AvatarPathResolver]) when one's
/// available, a placeholder person icon otherwise. Never `Image.network`:
/// like every other photo in this app, avatars aren't publicly reachable.
final class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    required this.resolver,
    required this.avatarId,
    required this.localFilePath,
    this.size = 96,
    super.key,
  });

  final AvatarPathResolver resolver;
  final String? avatarId;
  final String? localFilePath;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

final class _ProfileAvatarState extends State<ProfileAvatar> {
  late Future<String?> _pathFuture = _resolve();

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarId != widget.avatarId ||
        oldWidget.localFilePath != widget.localFilePath) {
      setState(() {
        _pathFuture = _resolve();
      });
    }
  }

  Future<String?> _resolve() => widget.resolver.resolve(
    avatarId: widget.avatarId,
    localFilePath: widget.localFilePath,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size / 2),
      child: FutureBuilder<String?>(
        future: _pathFuture,
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done ||
              path == null) {
            return _placeholder(colors);
          }
          return Image.file(
            File(path),
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _placeholder(colors),
          );
        },
      ),
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
