import 'package:beebase/core/location/location_failure.dart';
import 'package:beebase/core/location/resolved_location.dart';
import 'package:beebase/utils/either.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Reads the device's current position and resolves it to a human-readable
/// address plus its raw coordinates. The address falls back to formatted
/// coordinates if reverse geocoding doesn't return anything.
class LocationService {
  LocationService();

  final Geocoding _geocoding = Geocoding();

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
        ResolvedLocation(address: await _resolveAddress(position), latitude: position.latitude, longitude: position.longitude),
      );
    } catch (_) {
      return const Left(LocationUnavailableFailure());
    }
  }

  Future<String> _resolveAddress(Position position) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isEmpty) return _formatCoordinates(position);

      final placemark = placemarks.first;
      final parts = [
        placemark.locality,
        placemark.administrativeArea,
        placemark.country,
      ].where((part) => part != null && part.trim().isNotEmpty);

      return parts.isEmpty ? _formatCoordinates(position) : parts.join(', ');
    } catch (_) {
      return _formatCoordinates(position);
    }
  }

  String _formatCoordinates(Position position) =>
      '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
}
