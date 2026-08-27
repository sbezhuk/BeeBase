part of '../apiary_details_page.dart';

final class _ApiaryDetailsActions extends StatelessWidget {
  const _ApiaryDetailsActions({
    required this.apiary,
    required this.isDeleting,
    required this.onEdited,
  });

  final Apiary apiary;
  final bool isDeleting;
  final ValueChanged<Apiary> onEdited;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isDeleting ? null : () => _edit(context),
            icon: const Icon(Icons.edit_outlined),
            label: Text('apiary.details.edit'.tr()),
          ),
        ),
        SizedBox(width: context.spacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isDeleting ? null : () => _confirmDelete(context),
            icon: isDeleting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.error,
                    ),
                  )
                : Icon(Icons.delete_outline, color: colors.error),
            label: Text(
              'apiary.details.delete'.tr(),
              style: TextStyle(color: colors.error),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await context.router.push<Apiary>(
      ApiaryFormRoute(apiary: apiary),
    );
    if (updated != null) onEdited(updated);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<ApiaryDeleteCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('apiary.details.deleteConfirmTitle'.tr()),
        content: Text('apiary.details.deleteConfirmMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('apiary.details.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('apiary.details.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) cubit.delete();
  }
}
