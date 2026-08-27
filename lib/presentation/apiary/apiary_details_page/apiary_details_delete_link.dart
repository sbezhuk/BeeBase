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
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
        showGlassActionSheet<void>(
          context: context,
          title: 'apiary.details.deleteConfirmTitle'.tr(),
          message: 'apiary.details.deleteConfirmMessage'.tr(),
          cancelLabel: 'apiary.details.cancel'.tr(),
          actions: [
            GlassActionSheetAction(
              label: 'apiary.details.delete'.tr(),
              icon: const Icon(CupertinoIcons.delete),
              style: GlassActionSheetStyle.destructive,
              onPressed: cubit.delete,
            ),
          ],
        );
      default:
        _confirmDeleteAndroid(context, cubit);
    }
  }

  Future<void> _confirmDeleteAndroid(BuildContext context, ApiaryDeleteCubit cubit) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: colors.error),
        title: Text('apiary.details.deleteConfirmTitle'.tr()),
        content: Text('apiary.details.deleteConfirmMessage'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text('apiary.details.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('apiary.details.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) cubit.delete();
  }
}
