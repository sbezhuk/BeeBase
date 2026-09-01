part of '../register_page.dart';

final class _TermsAndConditionsNotice extends StatelessWidget {
  const _TermsAndConditionsNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      child: Text.rich(
        TextSpan(
          style: context.textStyles.authMuted,
          children: [
            TextSpan(text: 'authentication.register.terms_notice.prefix'.tr()),
            TextSpan(
              text: 'authentication.register.terms_notice.terms_and_conditions'.tr(),
              style: context.textStyles.authLink,
            ),
            TextSpan(text: 'authentication.register.terms_notice.and'.tr()),
            TextSpan(
              text: 'authentication.register.terms_notice.privacy_policy'.tr(),
              style: context.textStyles.authLink,
            ),
            TextSpan(text: 'authentication.register.terms_notice.suffix'.tr()),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
