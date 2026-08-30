part of '../apiary_details_page.dart';

/// Entry point into this apiary's hives — the only place [HiveListRoute] is
/// reached from, so a hive is never listed/created/edited outside the
/// context of the apiary the user picked here.
final class _ApiaryDetailsHivesLink extends StatelessWidget {
  const _ApiaryDetailsHivesLink({required this.apiary});

  final Apiary apiary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.router.root.push(
        HiveListRoute(apiaryId: apiary.id, apiaryName: apiary.name),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
        child: Row(
          children: [
            Icon(Icons.hive_outlined, size: 18, color: colors.text.secondary),
            SizedBox(width: context.spacing.xs),
            Expanded(
              child: Text(
                'apiary.details.manageHives'.tr(),
                style: context.textStyles.body,
              ),
            ),
            Icon(Icons.chevron_right, color: colors.text.secondary),
          ],
        ),
      ),
    );
  }
}
