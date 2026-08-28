part of '../apiary_details_page.dart';

final class _ApiaryDetailsBody extends StatelessWidget {
  const _ApiaryDetailsBody({required this.apiary, required this.isDeleting});

  final Apiary apiary;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasLocation = apiary.location != null && apiary.location!.isNotEmpty;
    final hasDescription = apiary.description != null && apiary.description!.isNotEmpty;
    final lat = apiary.lat;
    final lon = apiary.lon;
    Widget sectionDivider() => Divider(color: colors.border, height: context.spacing.xl);
    return SliverPadding(
      padding: EdgeInsets.only(bottom: context.spacing.lg),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: context.spacing.md),
            ApiaryMapPhoto(
              latitude: apiary.lat,
              longitude: apiary.lon,
              height: 220,
              fallback: const ApiaryPhotoPlaceholder(height: 220),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.md, context.spacing.md, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('apiary.details.sectionLabel'.tr(), style: context.textStyles.label.copyWith(color: colors.honeyMuted)),
                  SizedBox(height: context.spacing.xs),
                  Text(apiary.name, style: context.textStyles.title),
                  SizedBox(height: context.spacing.sm),
                  _ApiaryDetailsDetailRow(
                    icon: Icons.calendar_today_outlined,
                    text: 'apiary.details.addedOn'.tr(namedArgs: {'date': apiary.createdAt.toApiaryDisplayDate()}),
                  ),
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
                              style: context.textStyles.label.copyWith(color: colors.honeyMuted),
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
                  _ApiaryDeleteLink(isDeleting: isDeleting),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
