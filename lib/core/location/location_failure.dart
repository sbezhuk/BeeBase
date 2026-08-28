part 'location_service_disabled_failure.dart';
part 'location_permission_denied_failure.dart';
part 'location_unavailable_failure.dart';

/// Why [LocationService.getCurrentLocation] could not resolve an address.
/// [messageKey] is a localization key, resolved with `.tr()` at the display
/// site — mirrors [Failure] without pulling in the networking-specific
/// [ErrorText] distinction, which doesn't apply here since there's no
/// server-originated raw message to preserve.
sealed class LocationFailure {
  const LocationFailure();

  String get messageKey;
}
