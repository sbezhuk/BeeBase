part of '../profile_page.dart';

/// A common (non-destructive) account-security action, styled as a plain
/// text link — same treatment `_ProfileLogoutLink` uses, but in the brand
/// color rather than the destructive one since changing a password isn't
/// a rare or dangerous action the way logging out is.
final class _ProfileChangePasswordLink extends StatelessWidget {
  const _ProfileChangePasswordLink();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => context.router.push(const ChangePasswordRoute()),
        child: Text(
          'profile.page.change_password'.tr(),
          style: context.textStyles.action.copyWith(color: context.colors.brand.primary),
        ),
      ),
    );
  }
}
