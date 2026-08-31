part of '../media_thumbnail.dart';

final class _MediaThumbnailFrame extends StatelessWidget {
  const _MediaThumbnailFrame({
    required this.width,
    required this.height,
    required this.colors,
    required this.child,
  });

  final double width;
  final double height;
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
