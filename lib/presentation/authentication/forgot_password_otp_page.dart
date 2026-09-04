import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/presentation/authentication/cubit/forgot_password_otp_cubit/forgot_password_otp_cubit.dart';
import 'package:beebase/presentation/authentication/extension/server_failure_message_extension.dart';
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

part 'forgot_password_otp_page/otp_field.dart';
part 'forgot_password_otp_page/form_content.dart';
part 'forgot_password_otp_page/submit_button.dart';

@RoutePage()
final class ForgotPasswordOtpPage extends StatefulWidget implements AutoRouteWrapper {
  const ForgotPasswordOtpPage({required this.flowToken, super.key});

  final String flowToken;

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(create: (_) => di.get<ForgotPasswordOtpCubit>(), child: this);
  }

  @override
  State<ForgotPasswordOtpPage> createState() => _ForgotPasswordOtpPageState();
}

final class _ForgotPasswordOtpPageState extends State<ForgotPasswordOtpPage> {
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
      context.read<ForgotPasswordOtpCubit>().verify(flowToken: widget.flowToken, otp: _otpController.text.trim());
    }
  }

  void _handleStateChange(BuildContext context, ForgotPasswordOtpState state) {
    if (state is ForgotPasswordOtpSuccess) {
      context.router.push(ResetPasswordRoute(resetToken: state.verification.resetToken));
    } else if (state is ForgotPasswordOtpError) {
      _handleError(state.failure);
    }
  }

  void _handleError(Failure failure) {
    final fields = failure is ServerFailure ? failure.fields : null;
    final fieldError = fields?['otp']?.authFieldErrorMessage;
    if (fieldError != null) {
      setState(() => _otpServerError = fieldError);
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
            child: BlocListener<ForgotPasswordOtpCubit, ForgotPasswordOtpState>(
              listener: _handleStateChange,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
                child: Form(
                  key: _formKey,
                  child: _ForgotPasswordOtpFormContent(
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
      ),
    );
  }
}
