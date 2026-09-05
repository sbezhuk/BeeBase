part of '../profile_page.dart';

/// A common (non-destructive) account-security action — styled as a regular
/// settings row (see `_ProfileSettingsTile`) rather than the plain text link
/// `_ProfileLogoutLink`/`_ProfileDeleteAccountLink` use, since changing a
/// password isn't a rare or dangerous action the way those are.
final class _ProfileChangePasswordLink extends StatelessWidget {
  const _ProfileChangePasswordLink();

  @override
  Widget build(BuildContext context) {
    return _ProfileSettingsTile(
      icon: Icons.lock_outline,
      title: 'profile.page.change_password'.tr(),
      showChevron: true,
      onTap: () => context.router.push(const ChangePasswordRoute()),
    );
  }
}
