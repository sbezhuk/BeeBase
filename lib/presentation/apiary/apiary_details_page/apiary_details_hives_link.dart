part of '../apiary_details_page.dart';

/// Entry point into this apiary's hives — the only place [HiveListRoute] is
/// reached from, so a hive is never listed/created/edited outside the
/// context of the apiary the user picked here.
final class _ApiaryDetailsHivesLink extends StatelessWidget {
  const _ApiaryDetailsHivesLink({required this.apiary, required this.hiveCount});

  final Apiary apiary;

  /// This apiary's real hive count — `null` while the initial fetch is
  /// still in flight, in which case no count text is shown yet.
  final int? hiveCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = hiveCount;
    return GestureDetector(
      onTap: () => context.router.root.push(HiveListRoute(apiaryId: apiary.id, apiaryName: apiary.name)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
        child: Row(
          children: [
            Icon(Icons.hive_outlined, size: 18, color: colors.text.secondary),
            SizedBox(width: context.spacing.xs),
            Expanded(child: Text('apiary.details.manage_hives'.tr(), style: context.textStyles.body)),
            if (count != null) ...[
              Text(
                count > 0 ? 'apiary.details.hives_count'.tr(namedArgs: {'count': '$count'}) : 'apiary.details.no_hives'.tr(),
                style: context.textStyles.label.copyWith(color: colors.text.secondary),
              ),
              SizedBox(width: context.spacing.xs),
            ],
            Icon(Icons.chevron_right, color: colors.text.secondary),
          ],
        ),
      ),
    );
  }
}
