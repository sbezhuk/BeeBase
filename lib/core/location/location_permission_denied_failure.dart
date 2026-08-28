part of 'location_failure.dart';

/// The app was denied permission to read the device's location.
final class LocationPermissionDeniedFailure extends LocationFailure {
  const LocationPermissionDeniedFailure();

  @override
  String get messageKey => 'apiary.form.location.errors.permissionDenied';
}
