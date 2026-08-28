import 'package:beebase/utils/app_config.dart';

/// Builds Mapbox Static Images API URLs — used to render a small map
/// thumbnail (e.g. an apiary's location) without embedding a live map view.
final class MapboxStaticHelper {
  MapboxStaticHelper._();

  static const String _baseUrl = 'api.mapbox.com';
  static const String _username = 'mapbox';
  static const String _styleId = 'light-v11';

  /// Generates a Mapbox Static Image URL centered on [latitude]/[longitude],
  /// with a pin marker at that same point.
  ///
  /// - [width] and [height]: Image dimensions in pixels. Max 1280x1280.
  /// - [zoom]: Zoom level (0-22).
  /// - [markerColor]: Hex color code (e.g. "FF0000") for the pin.
  /// - [isRetina]: If true, adds @2x suffix for high-density displays.
  static String generateUrl({
    required double latitude,
    required double longitude,
    int width = 600,
    int height = 400,
    double zoom = 13.0,
    String markerColor = 'F7A21E',
    bool isRetina = true,
  }) {
    final retinaSuffix = isRetina ? '@2x' : '';
    final overlay = _marker(latitude: latitude, longitude: longitude, color: markerColor);
    final viewport = '$longitude,$latitude,${_formatNum(zoom)}';

    final path = '/styles/v1/$_username/$_styleId/static/$overlay/$viewport/${width}x$height$retinaSuffix';

    final uri = Uri.https(_baseUrl, path, {
      'access_token': AppConfig.mapboxPublicKey,
      'attribution': 'false',
      'logo': 'false',
    });

    return uri.toString();
  }

  static String _marker({required double latitude, required double longitude, required String color}) {
    final cleanColor = color.replaceAll('#', '');
    final hexColor = RegExp(r'^[0-9a-fA-F]{3,6}$').hasMatch(cleanColor) ? cleanColor : 'F7A21E';

    // Mapbox format: pin-size+color(lon,lat)
    return 'pin-s+$hexColor($longitude,$latitude)';
  }

  static String _formatNum(double value) {
    return value.toStringAsFixed(4).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
