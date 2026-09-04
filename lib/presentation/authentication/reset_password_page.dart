import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/presentation/authentication/extension/server_failure_message_extension.dart';
import 'package:beebase/presentation/authentication/cubit/reset_password_cubit/reset_password_cubit.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/honeycomb_pattern.dart';
import 'package:beebase/presentation/component/text_field/app_text_field.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'reset_password_page/new_password_field.dart';
part 'reset_password_page/confirm_password_field.dart';
part 'reset_password_page/form_content.dart';
part 'reset_password_page/submit_button.dart';

@RoutePage()
final class ResetPasswordPage extends StatefulWidget implements AutoRouteWrapper {
  const ResetPasswordPage({required this.resetToken, super.key});

  final String resetToken;

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(create: (_) => di.get<ResetPasswordCubit>(), child: this);
  }

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

final class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _newPasswordServerError;
  String? _confirmPasswordServerError;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ResetPasswordCubit>().confirm(
        resetToken: widget.resetToken,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
    }
  }

  void _handleStateChange(BuildContext context, ResetPasswordState state) {
    if (state is ResetPasswordSuccess) {
      context.router.replaceAll([const ResetPasswordSuccessRoute()]);
    } else if (state is ResetPasswordError) {
      _handleError(state.failure);
    }
  }

  void _handleError(Failure failure) {
    final fields = failure is ServerFailure ? failure.fields : null;
    final newPasswordError = fields?['new_password']?.authFieldErrorMessage;
    final confirmPasswordError = fields?['confirm_password']?.authFieldErrorMessage;
    if (newPasswordError != null || confirmPasswordError != null) {
      setState(() {
        _newPasswordServerError = newPasswordError;
        _confirmPasswordServerError = confirmPasswordError;
      });
      _formKey.currentState?.validate();
      return;
    }
    AppSnackBar.show(context, message: failure.message.resolve(), variant: AppSnackBarVariant.error);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
            child: BlocListener<ResetPasswordCubit, ResetPasswordState>(
              listener: _handleStateChange,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
                child: Form(
                  key: _formKey,
                  child: _ResetPasswordFormContent(
                    newPasswordController: _newPasswordController,
                    confirmPasswordController: _confirmPasswordController,
                    newPasswordServerError: _newPasswordServerError,
                    confirmPasswordServerError: _confirmPasswordServerError,
                    onNewPasswordChanged: () => setState(() => _newPasswordServerError = null),
                    onConfirmPasswordChanged: () => setState(() => _confirmPasswordServerError = null),
                    onSubmit: _submit,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
