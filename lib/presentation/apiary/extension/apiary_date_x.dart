import 'package:intl/intl.dart';

/// Formats apiary timestamps for display — a single shared implementation so
/// the details page and any future screen render dates identically.
extension ApiaryDateX on DateTime {
  String toApiaryDisplayDate() => DateFormat.yMMMd().format(toLocal());
}
