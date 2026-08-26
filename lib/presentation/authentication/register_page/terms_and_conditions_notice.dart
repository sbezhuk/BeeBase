part of '../register_page.dart';

final class _TermsAndConditionsNotice extends StatelessWidget {
  const _TermsAndConditionsNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      child: Text.rich(
        TextSpan(
          style: AppTextStyles.authMuted,
          children: [
            TextSpan(text: 'authentication.register.termsNotice.prefix'.tr()),
            TextSpan(text: 'authentication.register.termsNotice.termsAndConditions'.tr(), style: AppTextStyles.authLink),
            TextSpan(text: 'authentication.register.termsNotice.and'.tr()),
            TextSpan(text: 'authentication.register.termsNotice.privacyPolicy'.tr(), style: AppTextStyles.authLink),
            TextSpan(text: 'authentication.register.termsNotice.suffix'.tr()),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
