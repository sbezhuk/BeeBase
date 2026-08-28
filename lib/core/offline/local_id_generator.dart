import 'dart:math';

/// Generates a temporary identity for an entity created while offline, so it
/// can exist locally — referenced by the UI and by its own pending
/// operation — before the server assigns a real id. Not `package:uuid` (not
/// a current dependency); collision odds are adequate for a single-device,
/// low-volume queue. Upgrade this if a second offline-capable entity needs
/// stronger guarantees.
abstract final class LocalIdGenerator {
  static final _random = Random();

  static const prefix = 'local-';

  static String generate() {
    final suffix = _random.nextInt(1 << 32).toRadixString(36);
    return '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$suffix';
  }

  static bool isLocal(String id) => id.startsWith(prefix);
}
