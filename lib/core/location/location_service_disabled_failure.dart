part of 'location_failure.dart';

/// The device's location services (GPS) are turned off entirely.
final class LocationServiceDisabledFailure extends LocationFailure {
  const LocationServiceDisabledFailure();

  @override
  String get messageKey => 'apiary.form.location.errors.serviceDisabled';
}
