part of '../profile_page.dart';

/// Logout, styled as a `_ProfileSettingsTile` row like every other action on
/// this page, tinted with `colors.status.error` instead of the brand color
/// so it still reads as a deliberate, rare action rather than a common
/// setting — without falling back to the plain floating text link the rest
/// of the page moved away from.
final class _ProfileLogoutLink extends StatelessWidget {
  const _ProfileLogoutLink();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _ProfileSettingsTile(
      icon: Icons.logout,
      iconColor: colors.status.error,
      iconBackgroundColor: colors.status.error.withValues(alpha: 0.12),
      titleColor: colors.status.error,
      title: 'profile.page.logout'.tr(),
      onTap: () => _confirmLogout(context),
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
