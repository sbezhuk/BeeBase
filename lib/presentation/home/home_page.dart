import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
final class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('BeeBase'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthenticationCubit>().logout())],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(context.spacing.lg),
          child: BlocBuilder<AuthenticationCubit, AuthenticationState>(
            builder: (context, state) {
              final email = switch (state) {
                AuthenticationAuthenticated(:final user) => user.email,
                _ => null,
              };
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome to BeeBase', style: context.textStyles.title),
                  SizedBox(height: context.spacing.sm),
                  if (email != null) Text(email, style: context.textStyles.body),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
