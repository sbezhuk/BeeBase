import 'dart:io';

import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

part 'cached_media_image/cached_media_image_frame.dart';

/// The one way a photo is rendered anywhere in this app — the gallery strip,
/// an Apiary/Hive hero preview, a profile avatar. Every entity that grows a
/// photo goes through this widget rather than reaching for `Image.network`
/// or rolling its own download-and-cache (BEEB-39).
///
/// It picks a source rather than taking one:
///  - [localFilePath], when there's no [imageUrl] yet — a just-picked photo
///    that hasn't finished uploading exists only as the picker's temp file.
///  - [imageUrl] otherwise — served through `MediaImageCacheManager`, the
///    single bounded disk cache shared by every image in the app. A
///    just-uploaded photo is already seeded there from the very bytes that
///    were sent, so this switch never costs a round trip.
final class CachedMediaImage extends StatelessWidget {
  const CachedMediaImage({
    required this.imageUrl,
    required this.localFilePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.placeholder,
    this.errorWidget,
    this.cacheManager,
    super.key,
  });

  final String? imageUrl;
  final String? localFilePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  /// Shown while a remote photo loads. Defaults to a spinner on the standard
  /// image frame; [ProfileAvatar] passes its person icon instead.
  final Widget? placeholder;

  /// Shown when there's nothing to render, or rendering failed.
  final Widget? errorWidget;

  /// Only injected by tests — production resolves the app-wide
  /// `MediaImageCacheManager` from [di], and only on the remote branch, so a
  /// widget rendering a local file never touches the container at all.
  final BaseCacheManager? cacheManager;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: borderRadius, child: _source(context));
  }

  Widget _source(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return _localSource(context);
    }
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: cacheManager ?? di<BaseCacheManager>(),
      cacheKey: url,
      width: width,
      height: height,
      fit: fit,
      // Decode at display size rather than full resolution: the framework's
      // ImageCache holds *decoded* bytes, so a strip of 72px thumbnails
      // otherwise costs as much memory as a screen of full-size photos.
      memCacheWidth: _cachePixels(width, devicePixelRatio),
      memCacheHeight: _cachePixels(height, devicePixelRatio),
      placeholder: (context, _) => placeholder ?? _loadingFrame(context),
      errorWidget: (context, _, _) => errorWidget ?? _errorFrame(context),
    );
  }

  Widget _localSource(BuildContext context) {
    final path = localFilePath;
    if (path == null) {
      return errorWidget ?? _errorFrame(context);
    }
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          errorWidget ?? _errorFrame(context),
    );
  }

  /// `null` for an unbounded dimension (a full-width hero preview passes
  /// `double.infinity`) — [CachedNetworkImage] then leaves that axis to
  /// scale from the other one.
  int? _cachePixels(double? logicalPixels, double devicePixelRatio) {
    if (logicalPixels == null || !logicalPixels.isFinite) {
      return null;
    }
    return (logicalPixels * devicePixelRatio).round();
  }

  Widget _loadingFrame(BuildContext context) {
    final colors = context.colors;
    return _CachedMediaImageFrame(
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

  Widget _errorFrame(BuildContext context) {
    final colors = context.colors;
    return _CachedMediaImageFrame(
      width: width,
      height: height,
      colors: colors,
      child: Icon(Icons.broken_image_outlined, color: colors.text.secondary),
    );
  }
}
