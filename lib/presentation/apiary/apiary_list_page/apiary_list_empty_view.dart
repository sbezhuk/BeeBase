part of '../apiary_list_page.dart';

final class _ApiaryListEmptyView extends StatelessWidget {
  const _ApiaryListEmptyView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(context.spacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hive_outlined,
                      size: 56,
                      color: context.colors.textSecondary,
                    ),
                    SizedBox(height: context.spacing.md),
                    Text(
                      'apiary.list.emptyTitle'.tr(),
                      style: context.textStyles.title,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: context.spacing.sm),
                    Text(
                      'apiary.list.emptySubtitle'.tr(),
                      style: context.textStyles.body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
