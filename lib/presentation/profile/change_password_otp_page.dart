import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/presentation/authentication/extension/server_failure_message_extension.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/profile/cubit/change_password_cubit/change_password_cubit.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/presentation/widgets/otp_input/otp_input_field.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'change_password_otp_page/otp_field.dart';
part 'change_password_otp_page/content.dart';
part 'change_password_otp_page/submit_button.dart';

/// Step 2 of the change-password flow: the actual `changePassword` API call
/// (current password + new password, carried over from [ChangePasswordPage])
/// fires here together with the OTP the user enters — so the password
/// change is only ever completed once OTP verification succeeds.
@RoutePage()
final class ChangePasswordOtpPage extends StatefulWidget
    implements AutoRouteWrapper {
  const ChangePasswordOtpPage({
    required this.currentPassword,
    required this.newPassword,
    super.key,
  });

  final String currentPassword;
  final String newPassword;

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (_) => di.get<ChangePasswordCubit>(),
      child: this,
    );
  }

  @override
  State<ChangePasswordOtpPage> createState() => _ChangePasswordOtpPageState();
}

final class _ChangePasswordOtpPageState extends State<ChangePasswordOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  String? _otpServerError;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ChangePasswordCubit>().submit(
        currentPassword: widget.currentPassword,
        newPassword: widget.newPassword,
        otp: _otpController.text.trim(),
      );
    }
  }

  void _handleStateChange(BuildContext context, ChangePasswordState state) {
    if (state is ChangePasswordSuccess) {
      AppSnackBar.show(
        context,
        message: 'profile.change_password.otp.success_message'.tr(),
        variant: AppSnackBarVariant.success,
      );
      context.router.replaceAll([const LoginRoute()]);
    } else if (state is ChangePasswordError) {
      _handleError(state.failure);
    }
  }

  void _handleError(Failure failure) {
    final fields = failure is ServerFailure ? failure.fields : null;
    final otpError = fields?['otp']?.authFieldErrorMessage;
    if (otpError != null) {
      setState(() => _otpServerError = otpError);
      _formKey.currentState?.validate();
      return;
    }

    // A current/new password error can only be fixed on the previous
    // screen, which collected those fields — surface it there by popping
    // with the message as the push's result rather than showing it here.
    final passwordError =
        fields?['current_password']?.authFieldErrorMessage ??
        fields?['new_password']?.authFieldErrorMessage;
    if (passwordError != null) {
      context.router.pop(passwordError);
      return;
    }

    AppSnackBar.show(
      context,
      message: failure.message.resolve(),
      variant: AppSnackBarVariant.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'profile.change_password.otp.title'.tr(),
      fadeEdges: true,
      slivers: [
        BlocListener<ChangePasswordCubit, ChangePasswordState>(
          listener: _handleStateChange,
          child: SliverPadding(
            padding: EdgeInsets.all(context.spacing.md),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: _ChangePasswordOtpContent(
                  otpController: _otpController,
                  otpServerError: _otpServerError,
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
