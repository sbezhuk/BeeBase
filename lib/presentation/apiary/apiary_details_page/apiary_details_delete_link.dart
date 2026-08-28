part of '../apiary_details_page.dart';

/// A plain destructive text link, not a boxed button — deletion is a rare,
/// deliberate action here, so it stays visually quiet until confirmed,
/// while edit (the common action) lives up in the nav bar instead.
final class _ApiaryDeleteLink extends StatelessWidget {
  const _ApiaryDeleteLink({required this.isDeleting});

  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: GestureDetector(
        onTap: isDeleting ? null : () => _confirmDelete(context),
        child: isDeleting
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(colors.error)),
              )
            : Text('apiary.details.delete'.tr(), style: context.textStyles.action.copyWith(color: colors.error)),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final cubit = context.read<ApiaryDeleteCubit>();
    showConfirmationSheet(
      context: context,
      title: 'apiary.details.deleteConfirmTitle'.tr(),
      message: 'apiary.details.deleteConfirmMessage'.tr(),
      confirmLabel: 'apiary.details.delete'.tr(),
      cancelLabel: 'apiary.details.cancel'.tr(),
      icon: Icons.delete_outline,
      onConfirm: cubit.delete,
    );
  }
}
