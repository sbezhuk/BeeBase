part of '../hive_details_page.dart';

/// Entry point into this hive's inspections — the only place
/// [InspectionListRoute] is reached from, so an inspection is never
/// listed/created/edited outside the context of the hive the user picked
/// here. Mirrors [_ApiaryDetailsHivesLink].
final class _HiveDetailsInspectionsLink extends StatelessWidget {
  const _HiveDetailsInspectionsLink({required this.hive});

  final Hive hive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () =>
          context.router.root.push(InspectionListRoute(hiveId: hive.id, hiveName: hive.name)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
        child: Row(
          children: [
            Icon(Icons.fact_check_outlined, size: 18, color: colors.text.secondary),
            SizedBox(width: context.spacing.xs),
            Expanded(
              child: Text('hive.details.manageInspections'.tr(), style: context.textStyles.body),
            ),
            Icon(Icons.chevron_right, color: colors.text.secondary),
          ],
        ),
      ),
    );
  }
}
