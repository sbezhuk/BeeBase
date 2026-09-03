import 'package:easy_localization/easy_localization.dart';

/// Formats a Recent Activity timestamp as "Today"/"Yesterday" for the last
/// two days, falling back to a short date (e.g. "28 Aug") otherwise.
extension DashboardActivityDateX on DateTime {
  String toDashboardActivityDisplayDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(year, month, day);
    final difference = today.difference(date).inDays;

    if (difference == 0) return 'dashboard.recent_activity.today'.tr();
    if (difference == 1) return 'dashboard.recent_activity.yesterday'.tr();
    return DateFormat.MMMd().format(this);
  }
}
