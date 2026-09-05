part of '../inspection_details_page.dart';

final class _InspectionDetailsBody extends StatelessWidget {
  const _InspectionDetailsBody({required this.inspection, required this.isDeleting});

  final Inspection inspection;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasNotes = inspection.notes.isNotEmpty;
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
              child: Icon(Icons.fact_check_outlined, size: 36, color: colors.brand.primary),
            ),
            SizedBox(height: context.spacing.md),
            Text('inspection.details.section_label'.tr(), style: context.textStyles.label.copyWith(color: colors.honey.muted)),
            SizedBox(height: context.spacing.xs),
            Text(inspection.date.toInspectionDisplayDate(), style: context.textStyles.title),
            if (inspection.syncStatus != SyncStatus.synced) ...[
              SizedBox(height: context.spacing.xs),
              Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 14, color: colors.honey.muted),
                  SizedBox(width: context.spacing.xs),
                  Text(
                    'inspection.sync_status.${inspection.syncStatus.name}'.tr(),
                    style: context.textStyles.label.copyWith(color: colors.honey.muted),
                  ),
                ],
              ),
            ],
            SizedBox(height: context.spacing.sm),
            _InspectionDetailsDetailRow(icon: Icons.category_outlined, text: inspection.type.label),
            SizedBox(height: context.spacing.xs),
            _InspectionDetailsDetailRow(
              icon: Icons.calendar_today_outlined,
              text: 'inspection.details.added_on'.tr(namedArgs: {'date': inspection.createdAt.toInspectionDisplayDate()}),
            ),
            sectionDivider(),
            const MediaGallerySection(),
            if (hasNotes) ...[
              sectionDivider(),
              _InspectionDetailsInfoSection(
                label: 'inspection.form.notes_label'.tr(),
                child: Text(inspection.notes, style: context.textStyles.body),
              ),
            ],
            SizedBox(height: context.spacing.xl),
            _InspectionDeleteLink(inspection: inspection, isDeleting: isDeleting),
          ],
        ),
      ),
    );
  }
}
