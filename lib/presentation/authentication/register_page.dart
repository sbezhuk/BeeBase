import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/presentation/authentication/auth_field_errors.dart';
import 'package:beebase/presentation/authentication/cubit/register_cubit/register_cubit.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/color.dart';
import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'register_page/email_field.dart';
part 'register_page/password_field.dart';
part 'register_page/submit_button.dart';

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
    return Scaffold(
      backgroundColor: AppColor.background,
      body: SafeArea(
        child: BlocListener<RegisterCubit, RegisterState>(
          listener: _handleStateChange,
          child: Padding(
            padding: EdgeInsets.all(context.spacing.lg),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  SizedBox(height: context.spacing.xl),
                  Text('authentication.register.title'.tr(), style: AppTextStyles.title),
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
                  TextButton(onPressed: () => context.router.pop(), child: Text('authentication.register.haveAccount'.tr())),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
