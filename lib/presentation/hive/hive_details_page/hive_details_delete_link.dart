part of '../hive_details_page.dart';

/// A plain destructive text link, not a boxed button — mirrors
/// [_ApiaryDeleteLink]. Deletion is a rare, deliberate action here, so it
/// stays visually quiet until confirmed, while edit (the common action)
/// lives up in the nav bar instead.
///
/// A never-synced ([Hive.isLocalOnly]) hive is always deletable, online or
/// off. A synced hive requires live connectivity — [HiveRepositoryImpl]
/// enforces this too, but hiding the link here (via [ConnectivityCubit])
/// avoids the user hitting the confirm sheet just to see it fail, and
/// explains why via [hive.details.delete_requires_connection].
final class _HiveDeleteLink extends StatelessWidget {
  const _HiveDeleteLink({required this.hive, required this.isDeleting});

  final Hive hive;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    if (hive.isLocalOnly) {
      return _buildLink(context);
    }
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        if (state is ConnectivityOffline) {
          return Center(
            child: Text(
              'hive.details.delete_requires_connection'.tr(),
              textAlign: TextAlign.center,
              style: context.textStyles.label.copyWith(
                color: context.colors.text.secondary,
              ),
            ),
          );
        }
        return _buildLink(context);
      },
    );
  }

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
