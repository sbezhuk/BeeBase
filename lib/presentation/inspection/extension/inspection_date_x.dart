import 'package:intl/intl.dart';

/// Formats inspection timestamps for display — a single shared
/// implementation so every screen renders dates identically. Mirrors
/// [HiveDateX].
extension InspectionDateX on DateTime {
  String toInspectionDisplayDate() => DateFormat.yMMMd().format(toLocal());
}
