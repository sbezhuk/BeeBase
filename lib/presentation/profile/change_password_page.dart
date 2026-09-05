import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/text_field/app_text_field.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

part 'change_password_page/current_password_field.dart';
part 'change_password_page/new_password_field.dart';
part 'change_password_page/confirm_password_field.dart';
part 'change_password_page/content.dart';
part 'change_password_page/submit_button.dart';

/// Step 1 of the change-password flow: collects and validates the current
/// and new password, then hands them to [ChangePasswordOtpPage] — which
/// makes the actual `changePassword` call together with the OTP the user
/// enters there. No API call happens on this screen, so it needs no cubit
/// of its own.
@RoutePage()
final class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

final class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isNavigating = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isNavigating || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isNavigating = true);
    final errorMessage = await context.router.push<String>(
      ChangePasswordOtpRoute(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      ),
    );
    if (!mounted) return;
    setState(() => _isNavigating = false);
    if (errorMessage != null) {
      AppSnackBar.show(
        context,
        message: errorMessage,
        variant: AppSnackBarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'profile.change_password.title'.tr(),
      fadeEdges: true,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(context.spacing.md),
          sliver: SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: _ChangePasswordContent(
                currentPasswordController: _currentPasswordController,
                newPasswordController: _newPasswordController,
                confirmPasswordController: _confirmPasswordController,
                isLoading: _isNavigating,
                onSubmit: _submit,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
