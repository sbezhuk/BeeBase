part of '../apiary_details_page.dart';

final class _ApiaryDetailsBody extends StatelessWidget {
  const _ApiaryDetailsBody({required this.apiary, required this.isDeleting});

  final Apiary apiary;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final hasLocation = apiary.location != null && apiary.location!.isNotEmpty;
    final hasDescription = apiary.description != null && apiary.description!.isNotEmpty;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(context.spacing.lg, context.spacing.md, context.spacing.lg, context.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLocation) ...[
            ApiarySectionCard(
              label: 'apiary.form.locationLabel'.tr(),
              child: Text(apiary.location!, style: context.textStyles.body),
            ),
            SizedBox(height: context.spacing.md),
          ],
          if (hasDescription) ...[
            ApiarySectionCard(
              label: 'apiary.form.descriptionLabel'.tr(),
              child: Text(apiary.description!, style: context.textStyles.body),
            ),
            SizedBox(height: context.spacing.md),
          ],
          _ApiaryDetailsDetailRow(
            icon: Icons.calendar_today_outlined,
            text: 'apiary.details.addedOn'.tr(namedArgs: {'date': apiary.createdAt.toApiaryDisplayDate()}),
          ),
          SizedBox(height: context.spacing.xl),
          _ApiaryDeleteLink(isDeleting: isDeleting),
        ],
      ),
    );
  }
}
