part of '../profile_page.dart';

/// A plain destructive text link, matching `_ApiaryDeleteLink`'s treatment
/// of rare, deliberate destructive actions — logout stays visually quiet
/// until confirmed, while edit (the common action) lives up in the nav bar.
final class _ProfileLogoutLink extends StatelessWidget {
  const _ProfileLogoutLink();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: GestureDetector(
        onTap: () => _confirmLogout(context),
        child: Text(
          'profile.page.logout'.tr(),
          style: context.textStyles.action.copyWith(color: colors.status.error),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final cubit = context.read<AuthenticationCubit>();
    showConfirmationSheet(
      context: context,
      title: 'profile.page.logout_confirm_title'.tr(),
      message: 'profile.page.logout_confirm_message'.tr(),
      confirmLabel: 'profile.page.logout'.tr(),
      cancelLabel: 'profile.page.logout_cancel'.tr(),
      icon: Icons.logout,
      onConfirm: cubit.logout,
    );
  }
}
