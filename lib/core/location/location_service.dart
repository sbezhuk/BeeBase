import 'package:beebase/core/location/location_failure.dart';
import 'package:beebase/core/location/resolved_location.dart';
import 'package:beebase/core/services/connectivity_service.dart';
import 'package:beebase/utils/either.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Reads the device's current position and resolves it to a human-readable
/// street + city address plus its raw coordinates. The address falls back to
/// formatted coordinates if reverse geocoding doesn't return anything, or to
/// a localized offline placeholder if the device has no connectivity, since
/// reverse geocoding needs a network call and would otherwise silently
/// degrade to raw coordinates in place of a street/city name.
class LocationService {
  LocationService({required this.connectivity});

  final Geocoding _geocoding = Geocoding();
  final IConnectivityService connectivity;

  Future<Either<LocationFailure, ResolvedLocation>> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const Left(LocationServiceDisabledFailure());
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return const Left(LocationPermissionDeniedFailure());
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return Right(
        ResolvedLocation(
          address: await resolveAddress(latitude: position.latitude, longitude: position.longitude),
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      return const Left(LocationUnavailableFailure());
    }
  }

  /// Reverse-geocodes [latitude]/[longitude] into a "street, city, region,
  /// country" address. Also used to re-resolve the address of an apiary that
  /// was created/updated offline — its coordinates were saved, but the
  /// address fell back to the offline placeholder since geocoding needs a
  /// network call — once connectivity is back and it syncs.
  Future<String> resolveAddress({required double latitude, required double longitude}) async {
    if (!await connectivity.isOnline) {
      return 'apiary.form.location.offline_address'.tr();
    }

    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return _formatCoordinates(latitude, longitude);

      final placemark = placemarks.first;
      final parts = [
        placemark.street,
        placemark.locality,
        placemark.administrativeArea,
        placemark.country,
      ].where((part) => part != null && part.trim().isNotEmpty);

      return parts.isEmpty ? _formatCoordinates(latitude, longitude) : parts.join(', ');
    } catch (_) {
      return _formatCoordinates(latitude, longitude);
    }
  }

  String _formatCoordinates(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}
