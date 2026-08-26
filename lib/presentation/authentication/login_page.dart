import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/presentation/authentication/auth_field_errors.dart';
import 'package:beebase/presentation/authentication/cubit/login_cubit/login_cubit.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'login_page/email_field.dart';
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
      context.router.replaceAll([const HomeRoute()]);
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      body: SafeArea(
        child: BlocListener<LoginCubit, LoginState>(
          listener: _handleStateChange,
          child: Padding(
            padding: EdgeInsets.all(context.spacing.lg),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  SizedBox(height: context.spacing.xl),
                  Text('authentication.login.title'.tr(), style: AppTextStyles.title),
                  SizedBox(height: context.spacing.lg),
                  _EmailField(
                    controller: _emailController,
                    serverError: _emailServerError,
                    onChanged: () => setState(() => _emailServerError = null),
                  ),
                  SizedBox(height: context.spacing.md),
                  _PasswordField(
                    controller: _passwordController,
                    serverError: _passwordServerError,
                    onChanged: () => setState(() => _passwordServerError = null),
                  ),
                  SizedBox(height: context.spacing.lg),
                  _SubmitButton(onPressed: _submit),
                  SizedBox(height: context.spacing.md),
                  TextButton(
                    onPressed: () => context.router.push(const RegisterRoute()),
                    child: Text('authentication.login.createAccount'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
