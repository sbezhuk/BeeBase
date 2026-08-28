import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/mapbox_static_helper.dart';
import 'package:flutter/material.dart';

/// Mapbox static-image thumbnail for a location — the shared photo slot
/// used by the list tile, the details page, and the form page's live
/// location preview. Takes raw coordinates rather than an [Apiary] so the
/// form can render a preview before an apiary exists to attach it to.
/// Renders [fallback] whenever there are no coordinates or the image fails
/// to load, and a spinner (never [AppColor.photoPlaceholder]) while loading.
final class ApiaryMapPhoto extends StatelessWidget {
  const ApiaryMapPhoto({
    required this.latitude,
    required this.longitude,
    required this.height,
    required this.fallback,
    this.borderRadius,
    super.key,
  });

  final double? latitude;
  final double? longitude;
  final double height;
  final Widget fallback;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lon = longitude;
    if (lat == null || lon == null) return fallback;

    final url = MapboxStaticHelper.generateUrl(latitude: lat, longitude: lon);
    final colors = context.colors;

    Widget image = Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: height,
          width: double.infinity,
          color: colors.honey.creamLight,
          alignment: Alignment.center,
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: colors.brand.primary),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => fallback,
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}
