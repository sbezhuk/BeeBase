import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/presentation/authentication/auth_field_errors.dart';
import 'package:beebase/presentation/authentication/cubit/login_cubit/login_cubit.dart';
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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'login_page/create_account_prompt.dart';
part 'login_page/email_field.dart';
part 'login_page/forgot_password_action.dart';
part 'login_page/form_content.dart';
part 'login_page/password_field.dart';
part 'login_page/submit_button.dart';

@RoutePage()
final class LoginPage extends StatefulWidget implements AutoRouteWrapper {
  const LoginPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(create: (_) => di.get<LoginCubit>(), child: this);
  }

  @override
  State<LoginPage> createState() => _LoginPageState();
}

final class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailServerError;
  String? _passwordServerError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<LoginCubit>().login(email: _emailController.text.trim(), password: _passwordController.text);
    }
  }

  void _handleStateChange(BuildContext context, LoginState state) {
    if (state is LoginSuccess) {
      switch (state.challenge) {
        case LoginOtpChallenge challenge:
          context.router.push(LoginOtpRoute(challengeToken: challenge.challengeToken));
        case TotpSetupChallenge challenge:
          context.router.push(TotpSetupRoute(challenge: challenge));
      }
    } else if (state is LoginError) {
      _handleLoginError(state.failure);
    }
  }

  void _handleLoginError(Failure failure) {
    final fieldErrors = AuthFieldErrors.fromFailure(failure);
    if (fieldErrors.hasErrors) {
      setState(() {
        _emailServerError = fieldErrors.email;
        _passwordServerError = fieldErrors.password;
      });
      _formKey.currentState?.validate();
      return;
    }
    final message = failure.message.resolve();
    AppSnackBar.show(context, message: message, variant: AppSnackBarVariant.error);
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
            child: BlocListener<LoginCubit, LoginState>(
              listener: _handleStateChange,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
                child: Form(
                  key: _formKey,
                  child: _LoginFormContent(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    emailServerError: _emailServerError,
                    passwordServerError: _passwordServerError,
                    onEmailChanged: () => setState(() => _emailServerError = null),
                    onPasswordChanged: () => setState(() => _passwordServerError = null),
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
