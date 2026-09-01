part of '../inspection_list_page.dart';

final class _InspectionListEmptyView extends StatelessWidget {
  const _InspectionListEmptyView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(child: HoneycombPattern(opacity: 0.16)),
                  Icon(Icons.fact_check_outlined, size: 48, color: colors.brand.primary),
                ],
              ),
            ),
            SizedBox(height: context.spacing.lg),
            Text(
              'inspection.list.empty_title'.tr(),
              style: context.textStyles.title,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.spacing.sm),
            Text(
              'inspection.list.empty_subtitle'.tr(),
              style: context.textStyles.body.copyWith(color: colors.text.secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
