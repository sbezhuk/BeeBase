part of '../apiary_list_page.dart';

final class _ApiaryListEmptyView extends StatelessWidget {
  const _ApiaryListEmptyView();

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
                  const ApiaryHexagonBadge(size: 64),
                ],
              ),
            ),
            SizedBox(height: context.spacing.lg),
            Text('apiary.list.empty_title'.tr(), style: context.textStyles.title, textAlign: TextAlign.center),
            SizedBox(height: context.spacing.sm),
            Text(
              'apiary.list.empty_subtitle'.tr(),
              style: context.textStyles.body.copyWith(color: colors.text.secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
