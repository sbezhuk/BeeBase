part of '../hive_details_page.dart';

final class _HiveDetailsBody extends StatelessWidget {
  const _HiveDetailsBody({required this.hive, required this.isDeleting});

  final Hive hive;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasDescription = hive.notes != null && hive.notes!.isNotEmpty;
    Widget sectionDivider() => Divider(color: colors.surface.border, height: context.spacing.xl);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.md, context.spacing.md, context.spacing.lg),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: colors.honey.border, shape: BoxShape.circle),
              child: Icon(Icons.hive_outlined, size: 36, color: colors.brand.primary),
            ),
            SizedBox(height: context.spacing.md),
            Text('hive.details.sectionLabel'.tr(), style: context.textStyles.label.copyWith(color: colors.honey.muted)),
            SizedBox(height: context.spacing.xs),
            Text(hive.name, style: context.textStyles.title),
            if (hive.syncStatus != HiveSyncStatus.synced) ...[
              SizedBox(height: context.spacing.xs),
              HiveSyncBadge(status: hive.syncStatus),
            ],
            SizedBox(height: context.spacing.sm),
            _HiveDetailsDetailRow(
              icon: Icons.calendar_today_outlined,
              text: 'hive.details.addedOn'.tr(namedArgs: {'date': hive.createdAt.toHiveDisplayDate()}),
            ),
            sectionDivider(),
            _HiveDetailsInspectionsLink(hive: hive),
            sectionDivider(),
            const MediaGallerySection(),
            if (hasDescription) ...[
              sectionDivider(),
              _HiveDetailsInfoSection(
                label: 'hive.form.descriptionLabel'.tr(),
                child: Text(hive.notes!, style: context.textStyles.body),
              ),
            ],
            SizedBox(height: context.spacing.xl),
            _HiveDeleteLink(hive: hive, isDeleting: isDeleting),
          ],
        ),
      ),
    );
  }
}
