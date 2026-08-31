part of '../media_thumbnail.dart';

/// Full-bleed scrim + spinner shown over a thumbnail while its photo is
/// uploading or being removed — makes an in-flight network call unmistakable,
/// on both the small gallery-strip tiles and the big hero preview (both
/// render through [MediaThumbnail]).
final class _MediaThumbnailOverlay extends StatelessWidget {
  const _MediaThumbnailOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      ),
    );
  }
}
