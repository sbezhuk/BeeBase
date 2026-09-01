part of '../apiary_details_page.dart';

final class _ApiaryDetailsBody extends StatelessWidget {
  const _ApiaryDetailsBody({required this.apiary, required this.isDeleting, required this.hiveCount});

  final Apiary apiary;
  final bool isDeleting;
  final int? hiveCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasLocation = apiary.location != null && apiary.location!.isNotEmpty;
    final hasDescription = apiary.description != null && apiary.description!.isNotEmpty;
    final lat = apiary.lat;
    final lon = apiary.lon;
    Widget sectionDivider() => Divider(color: colors.surface.border, height: context.spacing.xl);
    return SliverPadding(
      padding: EdgeInsets.only(bottom: context.spacing.lg),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: context.spacing.md),
            ApiaryPreviewImage(apiary: apiary, height: 220),
            Padding(
              padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.md, context.spacing.md, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('apiary.details.sectionLabel'.tr(), style: context.textStyles.label.copyWith(color: colors.honey.muted)),
                  SizedBox(height: context.spacing.xs),
                  Text(apiary.name, style: context.textStyles.title),
                  if (apiary.syncStatus != ApiarySyncStatus.synced) ...[
                    SizedBox(height: context.spacing.xs),
                    ApiarySyncBadge(status: apiary.syncStatus),
                  ],
                  SizedBox(height: context.spacing.sm),
                  _ApiaryDetailsDetailRow(
                    icon: Icons.calendar_today_outlined,
                    text: 'apiary.details.addedOn'.tr(namedArgs: {'date': apiary.createdAt.toApiaryDisplayDate()}),
                  ),
                  sectionDivider(),
                  _ApiaryDetailsHivesLink(apiary: apiary, hiveCount: hiveCount),
                  sectionDivider(),
                  const MediaGallerySection(),
                  if (hasLocation) ...[
                    sectionDivider(),
                    _ApiaryDetailsInfoSection(
                      label: 'apiary.form.locationLabel'.tr(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(apiary.location!, style: context.textStyles.body),
                          if (lat != null && lon != null) ...[
                            SizedBox(height: context.spacing.xs),
                            Text(
                              '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
                              style: context.textStyles.label.copyWith(color: colors.honey.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (hasDescription) ...[
                    sectionDivider(),
                    _ApiaryDetailsInfoSection(
                      label: 'apiary.form.descriptionLabel'.tr(),
                      child: Text(apiary.description!, style: context.textStyles.body),
                    ),
                  ],
                  SizedBox(height: context.spacing.xl),
                  _ApiaryDeleteLink(apiary: apiary, isDeleting: isDeleting),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
