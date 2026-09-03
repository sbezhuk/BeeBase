import 'package:intl/intl.dart';

extension ProfileDateX on DateTime {
  String toProfileDisplayDate() => DateFormat.yMMMd().format(toLocal());
}
