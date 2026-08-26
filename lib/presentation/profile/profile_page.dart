import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
final class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('profile.page.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthenticationCubit>().logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.spacing.lg),
          child: BlocBuilder<AuthenticationCubit, AuthenticationState>(
            builder: (context, state) {
              final email = switch (state) {
                AuthenticationAuthenticated(:final user) => user.email,
                _ => null,
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (email != null)
                    Text(email, style: context.textStyles.title),
                  SizedBox(height: context.spacing.sm),
                  Text(
                    'profile.page.placeholder'.tr(),
                    style: context.textStyles.body,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
