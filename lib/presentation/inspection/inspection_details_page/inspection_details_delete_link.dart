part of '../inspection_details_page.dart';

/// A plain destructive text link, not a boxed button — mirrors
/// [_HiveDeleteLink]. Deletion is a rare, deliberate action here, so it
/// stays visually quiet until confirmed, while edit (the common action)
/// lives up in the nav bar instead.
final class _InspectionDeleteLink extends StatelessWidget {
  const _InspectionDeleteLink({required this.inspection, required this.isDeleting});

  final Inspection inspection;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) => _buildLink(context);

  Widget _buildLink(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: GestureDetector(
        onTap: isDeleting ? null : () => _confirmDelete(context),
        child: isDeleting
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(colors.status.error),
                ),
              )
            : Text(
                'inspection.details.delete'.tr(),
                style: context.textStyles.action.copyWith(color: colors.status.error),
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final cubit = context.read<InspectionDeleteCubit>();
    showConfirmationSheet(
      context: context,
      title: 'inspection.details.delete_confirm_title'.tr(),
      message: 'inspection.details.delete_confirm_message'.tr(),
      confirmLabel: 'inspection.details.delete'.tr(),
      cancelLabel: 'inspection.details.cancel'.tr(),
      icon: Icons.delete_outline,
      onConfirm: cubit.delete,
    );
  }
}
