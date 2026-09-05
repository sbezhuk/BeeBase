import 'package:auto_route/auto_route.dart';
import 'package:beebase/data/data_source/interface/apiary_local_data_source.dart';
import 'package:beebase/data/data_source/interface/hive_local_data_source.dart';
import 'package:beebase/data/data_source/interface/inspection_local_data_source.dart';
import 'package:beebase/data/sync/data_synchronizer.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/profile/avatar_image_resolver.dart';
import 'package:beebase/presentation/profile/cubit/profile_cubit/profile_cubit.dart';
import 'package:beebase/presentation/profile/extension/profile_date_x.dart';
import 'package:beebase/presentation/profile/widget/profile_avatar.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold_action.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/presentation/widgets/confirmation_sheet/confirmation_sheet.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'profile_page/profile_language_section.dart';
part 'profile_page/profile_sync_section.dart';
part 'profile_page/profile_header.dart';
part 'profile_page/profile_info_section.dart';
part 'profile_page/profile_info_row.dart';
part 'profile_page/profile_app_version.dart';
part 'profile_page/profile_change_password_link.dart';
part 'profile_page/profile_logout_link.dart';

@RoutePage()
final class ProfilePage extends StatelessWidget implements AutoRouteWrapper {
  const ProfilePage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (_) => di.get<ProfileCubit>()..load(),
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationCubit, AuthenticationState>(
      builder: (context, state) {
        final user = switch (state) {
          AuthenticationAuthenticated(:final user) => user,
          _ => null,
        };
        return AppScaffold(
          title: 'profile.page.title'.tr(),
          showBackButton: false,
          fadeEdges: true,
          trailingAction: user == null
              ? null
              : AppScaffoldAction(
                  label: 'profile.page.edit'.tr(),
                  materialIcon: Icons.edit_outlined,
                  cupertinoIcon: CupertinoIcons.pencil,
                  onPressed: () =>
                      context.router.push(ProfileEditRoute(user: user)),
                ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(context.spacing.md),
              sliver: SliverToBoxAdapter(
                child: user == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileHeader(user: user),
                          SizedBox(height: context.spacing.xl),
                          _ProfileInfoSection(user: user),
                          SizedBox(height: context.spacing.xl),
                          const _ProfileLanguageSection(),
                          SizedBox(height: context.spacing.xl),
                          const ProfileSyncSection(),
                          SizedBox(height: context.spacing.xl),
                          const _ProfileAppVersion(),
                          SizedBox(height: context.spacing.lg),
                          const _ProfileChangePasswordLink(),
                          SizedBox(height: context.spacing.md),
                          const _ProfileLogoutLink(),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
