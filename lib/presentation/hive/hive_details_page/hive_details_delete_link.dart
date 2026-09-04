part of '../hive_details_page.dart';

/// A plain destructive text link, not a boxed button — mirrors
/// [_ApiaryDeleteLink]. Deletion is a rare, deliberate action here, so it
/// stays visually quiet until confirmed, while edit (the common action)
/// lives up in the nav bar instead.
final class _HiveDeleteLink extends StatelessWidget {
  const _HiveDeleteLink({required this.hive, required this.isDeleting});

  final Hive hive;
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
                'hive.details.delete'.tr(),
                style: context.textStyles.action.copyWith(
                  color: colors.status.error,
                ),
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final cubit = context.read<HiveDeleteCubit>();
    showConfirmationSheet(
      context: context,
      title: 'hive.details.delete_confirm_title'.tr(),
      message: 'hive.details.delete_confirm_message'.tr(),
      confirmLabel: 'hive.details.delete'.tr(),
      cancelLabel: 'hive.details.cancel'.tr(),
      icon: Icons.delete_outline,
      onConfirm: cubit.delete,
    );
  }
}
