part of '../totp_setup_page.dart';

final class _QrCodeCard extends StatelessWidget {
  const _QrCodeCard({required this.challenge});

  final TotpSetupChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(context.spacing.md),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: QrImageView(data: challenge.otpauthUri, size: 200, backgroundColor: Colors.white),
        ),
        SizedBox(height: context.spacing.md),
        Text(
          'authentication.totp_setup.secret_fallback_label'.tr(),
          textAlign: TextAlign.center,
          style: context.textStyles.authMuted,
        ),
        SizedBox(height: context.spacing.xs),
        SelectableText(
          challenge.secret,
          textAlign: TextAlign.center,
          style: context.textStyles.authSubtitle.copyWith(color: colors.brand.primary, letterSpacing: 2),
        ),
      ],
    );
  }
}
