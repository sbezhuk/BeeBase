import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/presentation/authentication/extension/server_failure_message_extension.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/text_field/app_text_field.dart';
import 'package:beebase/presentation/profile/cubit/change_password_cubit/change_password_cubit.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'change_password_page/current_password_field.dart';
part 'change_password_page/new_password_field.dart';
part 'change_password_page/confirm_password_field.dart';
part 'change_password_page/otp_field.dart';
part 'change_password_page/content.dart';
part 'change_password_page/submit_button.dart';

@RoutePage()
final class ChangePasswordPage extends StatefulWidget implements AutoRouteWrapper {
  const ChangePasswordPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(create: (_) => di.get<ChangePasswordCubit>(), child: this);
  }

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

final class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  String? _currentPasswordServerError;
  String? _newPasswordServerError;
  String? _otpServerError;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ChangePasswordCubit>().submit(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        otp: _otpController.text.trim(),
      );
    }
  }

  void _handleStateChange(BuildContext context, ChangePasswordState state) {
    if (state is ChangePasswordSuccess) {
      AppSnackBar.show(
        context,
        message: 'profile.change_password.success_message'.tr(),
        variant: AppSnackBarVariant.success,
      );
    } else if (state is ChangePasswordError) {
      _handleError(state.failure);
    }
  }

  void _handleError(Failure failure) {
    final fields = failure is ServerFailure ? failure.fields : null;
    final currentPasswordError = fields?['current_password']?.authFieldErrorMessage;
    final newPasswordError = fields?['new_password']?.authFieldErrorMessage;
    final otpError = fields?['otp']?.authFieldErrorMessage;
    if (currentPasswordError != null || newPasswordError != null || otpError != null) {
      setState(() {
        _currentPasswordServerError = currentPasswordError;
        _newPasswordServerError = newPasswordError;
        _otpServerError = otpError;
      });
      _formKey.currentState?.validate();
      return;
    }
    AppSnackBar.show(context, message: failure.message.resolve(), variant: AppSnackBarVariant.error);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'profile.change_password.title'.tr(),
      fadeEdges: true,
      slivers: [
        BlocListener<ChangePasswordCubit, ChangePasswordState>(
          listener: _handleStateChange,
          child: SliverPadding(
            padding: EdgeInsets.all(context.spacing.md),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: _ChangePasswordContent(
                  currentPasswordController: _currentPasswordController,
                  newPasswordController: _newPasswordController,
                  confirmPasswordController: _confirmPasswordController,
                  otpController: _otpController,
                  currentPasswordServerError: _currentPasswordServerError,
                  newPasswordServerError: _newPasswordServerError,
                  otpServerError: _otpServerError,
                  onCurrentPasswordChanged: () => setState(() => _currentPasswordServerError = null),
                  onNewPasswordChanged: () => setState(() => _newPasswordServerError = null),
                  onOtpChanged: () => setState(() => _otpServerError = null),
                  onSubmit: _submit,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
