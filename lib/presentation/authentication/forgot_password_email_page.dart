import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/presentation/authentication/auth_field_errors.dart';
import 'package:beebase/presentation/authentication/cubit/forgot_password_email_cubit/forgot_password_email_cubit.dart';
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

part 'forgot_password_email_page/email_field.dart';
part 'forgot_password_email_page/form_content.dart';
part 'forgot_password_email_page/submit_button.dart';

@RoutePage()
final class ForgotPasswordEmailPage extends StatefulWidget implements AutoRouteWrapper {
  const ForgotPasswordEmailPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(create: (_) => di.get<ForgotPasswordEmailCubit>(), child: this);
  }

  @override
  State<ForgotPasswordEmailPage> createState() => _ForgotPasswordEmailPageState();
}

final class _ForgotPasswordEmailPageState extends State<ForgotPasswordEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String? _emailServerError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ForgotPasswordEmailCubit>().submit(email: _emailController.text.trim());
    }
  }

  void _handleStateChange(BuildContext context, ForgotPasswordEmailState state) {
    if (state is ForgotPasswordEmailSuccess) {
      context.router.push(ForgotPasswordOtpRoute(flowToken: state.flow.flowToken));
    } else if (state is ForgotPasswordEmailError) {
      _handleError(state.failure);
    }
  }

  void _handleError(Failure failure) {
    final fieldErrors = AuthFieldErrors.fromFailure(failure);
    if (fieldErrors.hasErrors) {
      setState(() => _emailServerError = fieldErrors.email);
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
            child: BlocListener<ForgotPasswordEmailCubit, ForgotPasswordEmailState>(
              listener: _handleStateChange,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
                child: Form(
                  key: _formKey,
                  child: _ForgotPasswordEmailFormContent(
                    emailController: _emailController,
                    emailServerError: _emailServerError,
                    onEmailChanged: () => setState(() => _emailServerError = null),
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
