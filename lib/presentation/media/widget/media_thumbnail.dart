import 'dart:io';

import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_item.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'media_thumbnail/media_thumbnail_frame.dart';
part 'media_thumbnail/media_thumbnail_overlay.dart';

/// Renders one [MediaGalleryItem]'s photo. Photos aren't publicly reachable
/// (`GET .../download` requires the bearer token), so this never uses
/// `Image.network` — it renders straight from [MediaGalleryItem.localFilePath]
/// when that file still exists, or asks the ambient `MediaGalleryCubit` to
/// download-and-cache a copy otherwise (see
/// `MediaGalleryCubit.resolveDisplayPath`).
final class MediaThumbnail extends StatefulWidget {
  const MediaThumbnail({
    required this.item,
    this.size = 72,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.key,
  });

  final MediaGalleryItem item;

  /// Used for both dimensions when [width]/[height] aren't given — the
  /// gallery strip's square tiles only ever set this.
  final double size;

  /// Override [size] independently per axis — e.g. a full-width, fixed-height
  /// hero preview (see `ApiaryPreviewImage`), which isn't square.
  final double? width;
  final double? height;

  final BorderRadius borderRadius;

  @override
  State<MediaThumbnail> createState() => _MediaThumbnailState();
}

final class _MediaThumbnailState extends State<MediaThumbnail> {
  late Future<String?> _pathFuture = _resolve();

  @override
  void didUpdateWidget(covariant MediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.localId != widget.item.localId ||
        oldWidget.item.localFilePath != widget.item.localFilePath) {
      // A block body, not `setState(() => _pathFuture = _resolve())` — an
      // assignment expression evaluates to its right-hand side, so the
      // arrow-function form implicitly returns `_resolve()`'s Future.
      // `setState` runs the callback (so the field is still reassigned) but
      // then throws "setState() callback argument returned a Future" before
      // reaching `markNeedsBuild()` — the new future is fetched but the
      // FutureBuilder is never actually told to rebuild with it, leaving the
      // old thumbnail frozen on screen.
      setState(() {
        _pathFuture = _resolve();
      });
    }
  }

  Future<String?> _resolve() =>
      context.read<MediaGalleryCubit>().resolveDisplayPath(widget.item);

  bool get _isBusy =>
      widget.item.status == MediaGalleryItemStatus.uploading ||
      widget.item.status == MediaGalleryItemStatus.removing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final width = widget.width ?? widget.size;
    final height = widget.height ?? widget.size;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          _image(context, colors, width, height),
          if (_isBusy) const Positioned.fill(child: _MediaThumbnailOverlay()),
        ],
      ),
    );
  }

  Widget _image(
    BuildContext context,
    AppColor colors,
    double width,
    double height,
  ) {
    return FutureBuilder<String?>(
      future: _pathFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _MediaThumbnailFrame(
            width: width,
            height: height,
            colors: colors,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(colors.brand.primary),
              ),
            ),
          );
        }
        final path = snapshot.data;
        if (path == null) {
          return _MediaThumbnailFrame(
            width: width,
            height: height,
            colors: colors,
            child: Icon(
              Icons.broken_image_outlined,
              color: colors.text.secondary,
            ),
          );
        }
        return Image.file(
          File(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _MediaThumbnailFrame(
            width: width,
            height: height,
            colors: colors,
            child: Icon(
              Icons.broken_image_outlined,
              color: colors.text.secondary,
            ),
          ),
        );
      },
    );
  }
}
