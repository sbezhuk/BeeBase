import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/honeycomb_pattern.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

@RoutePage()
final class ResetPasswordSuccessPage extends StatelessWidget {
  const ResetPasswordSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.honey.cream, colors.honey.creamLight, colors.surface.background],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, height: 320, child: HoneycombPattern()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 72, color: colors.brand.primary),
                  SizedBox(height: context.spacing.lg),
                  Text(
                    'authentication.reset_password_success.title'.tr(),
                    textAlign: TextAlign.center,
                    style: context.textStyles.authTitle,
                  ),
                  SizedBox(height: context.spacing.sm),
                  Text(
                    'authentication.reset_password_success.subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: context.textStyles.authSubtitle,
                  ),
                  SizedBox(height: context.spacing.xl),
                  PrimaryButton(
                    label: 'authentication.reset_password_success.back_to_login'.tr(),
                    onPressed: () => context.router.replaceAll([const LoginRoute()]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
