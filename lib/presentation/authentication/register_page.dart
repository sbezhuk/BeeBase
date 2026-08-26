import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/presentation/authentication/auth_field_errors.dart';
import 'package:beebase/presentation/authentication/cubit/register_cubit/register_cubit.dart';
import 'package:beebase/presentation/authentication/widget/auth_text_field.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/honeycomb_pattern.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'register_page/email_field.dart';
part 'register_page/form_content.dart';
part 'register_page/login_prompt.dart';
part 'register_page/password_field.dart';
part 'register_page/submit_button.dart';
part 'register_page/terms_and_conditions_notice.dart';

@RoutePage()
final class RegisterPage extends StatefulWidget implements AutoRouteWrapper {
  const RegisterPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(create: (_) => di.get<RegisterCubit>(), child: this);
  }

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

final class _RegisterPageState extends State<RegisterPage> {
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
      context.read<RegisterCubit>().register(email: _emailController.text.trim(), password: _passwordController.text);
    }
  }

  void _handleStateChange(BuildContext context, RegisterState state) {
    if (state is RegisterSuccess) {
      context.router.replaceAll([const HomeRoute()]);
    } else if (state is RegisterError) {
      _handleRegisterError(state.failure);
    }
  }

  void _handleRegisterError(Failure failure) {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

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
                  colors: [colors.honeyCream, colors.honeyCreamLight, colors.background],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, height: 320, child: HoneycombPattern()),
          SafeArea(
            child: BlocListener<RegisterCubit, RegisterState>(
              listener: _handleStateChange,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
                child: Form(
                  key: _formKey,
                  child: _RegisterFormContent(
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
