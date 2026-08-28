part of 'location_failure.dart';

/// Permission and service checks passed, but the position couldn't be
/// determined (e.g. no fix yet, or the platform call failed unexpectedly).
final class LocationUnavailableFailure extends LocationFailure {
  const LocationUnavailableFailure();

  @override
  String get messageKey => 'apiary.form.location.errors.unavailable';
}
