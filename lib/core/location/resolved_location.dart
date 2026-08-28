/// A device position resolved to something displayable and persistable: a
/// human-readable address (falling back to formatted coordinates if reverse
/// geocoding fails — see [LocationService]) plus the raw latitude/longitude,
/// which the apiary API now stores alongside the address.
final class ResolvedLocation {
  const ResolvedLocation({required this.address, required this.latitude, required this.longitude});

  final String address;
  final double latitude;
  final double longitude;
}
