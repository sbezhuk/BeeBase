part of '../hive_details_page.dart';

final class _HiveDetailsBody extends StatelessWidget {
  const _HiveDetailsBody({required this.hive, required this.isDeleting});

  final Hive hive;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasDescription = hive.notes != null && hive.notes!.isNotEmpty;
    Widget sectionDivider() =>
        Divider(color: colors.surface.border, height: context.spacing.xl);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        context.spacing.md,
        context.spacing.md,
        context.spacing.md,
        context.spacing.lg,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.honey.border,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hive_outlined,
                size: 36,
                color: colors.brand.primary,
              ),
            ),
            SizedBox(height: context.spacing.md),
            Text(
              'hive.details.section_label'.tr(),
              style: context.textStyles.label.copyWith(
                color: colors.honey.muted,
              ),
            ),
            SizedBox(height: context.spacing.xs),
            Text(hive.name, style: context.textStyles.title),
            if (hive.syncStatus != SyncStatus.synced) ...[
              SizedBox(height: context.spacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 14,
                    color: colors.honey.muted,
                  ),
                  SizedBox(width: context.spacing.xs),
                  Text(
                    'hive.sync_status.${hive.syncStatus.name}'.tr(),
                    style: context.textStyles.label.copyWith(
                      color: colors.honey.muted,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: context.spacing.sm),
            _HiveDetailsDetailRow(
              icon: Icons.calendar_today_outlined,
              text: 'hive.details.added_on'.tr(
                namedArgs: {'date': hive.createdAt.toHiveDisplayDate()},
              ),
            ),
            sectionDivider(),
            _HiveDetailsInspectionsLink(hive: hive),
            sectionDivider(),
            const MediaGallerySection(),
            if (hasDescription) ...[
              sectionDivider(),
              _HiveDetailsInfoSection(
                label: 'hive.form.description_label'.tr(),
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
