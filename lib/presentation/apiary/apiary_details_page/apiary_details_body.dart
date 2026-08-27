part of '../apiary_details_page.dart';

final class _ApiaryDetailsBody extends StatelessWidget {
  const _ApiaryDetailsBody({
    required this.apiary,
    required this.isDeleting,
    required this.onEdited,
  });

  final Apiary apiary;
  final bool isDeleting;
  final ValueChanged<Apiary> onEdited;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(apiary.name, style: context.textStyles.title),
          if (apiary.location != null && apiary.location!.isNotEmpty) ...[
            SizedBox(height: context.spacing.sm),
            _ApiaryDetailsDetailRow(
              icon: Icons.place_outlined,
              text: apiary.location!,
            ),
          ],
          if (apiary.description != null && apiary.description!.isNotEmpty) ...[
            SizedBox(height: context.spacing.md),
            Text(apiary.description!, style: context.textStyles.body),
          ],
          SizedBox(height: context.spacing.xl),
          _ApiaryDetailsActions(
            apiary: apiary,
            isDeleting: isDeleting,
            onEdited: onEdited,
          ),
        ],
      ),
    );
  }
}
