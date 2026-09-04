part of '../cached_media_image.dart';

/// The neutral tile a photo occupies while it loads or when it can't be
/// shown — same footprint as the image itself, so nothing reflows when the
/// real thing arrives.
final class _CachedMediaImageFrame extends StatelessWidget {
  const _CachedMediaImageFrame({
    required this.width,
    required this.height,
    required this.colors,
    required this.child,
  });

  final double? width;
  final double? height;
  final AppColor colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: colors.honey.creamLight,
      alignment: Alignment.center,
      child: child,
    );
  }
}
