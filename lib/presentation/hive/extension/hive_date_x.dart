import 'package:intl/intl.dart';

/// Formats hive timestamps for display — a single shared implementation so
/// the details page and any future screen render dates identically. Mirrors
/// [ApiaryDateX].
extension HiveDateX on DateTime {
  String toHiveDisplayDate() => DateFormat.yMMMd().format(toLocal());
}
