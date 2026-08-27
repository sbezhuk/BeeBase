import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_list_cubit/apiary_list_cubit.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'apiary_list_page/apiary_list_body.dart';
part 'apiary_list_page/apiary_list_tile.dart';
part 'apiary_list_page/apiary_list_empty_view.dart';
part 'apiary_list_page/apiary_list_error_view.dart';

/// The "create" action lives outside this page now — [MainPage] renders it
/// as a platform-styled primary action beside/above the bottom nav bar (see
/// [BottomNavPrimaryAction]) whenever this tab is active, since only the
/// shell knows how to place it correctly relative to the nav bar on each
/// platform. This page's own job is just to reflect the list; it picks up
/// anything created, edited, or deleted elsewhere via [ApiaryListCubit]'s
/// subscription to [ApiaryListRefreshNotifier] rather than by observing
/// navigation — [ApiaryFormRoute] and [ApiaryDetailsRoute] are root-level
/// routes, so AutoRoute's `didPopNext` never reaches this page.
@RoutePage()
final class ApiaryListPage extends StatefulWidget implements AutoRouteWrapper {
  const ApiaryListPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (_) => di.get<ApiaryListCubit>()..loadApiaries(),
      child: this,
    );
  }

  @override
  State<ApiaryListPage> createState() => _ApiaryListPageState();
}

final class _ApiaryListPageState extends State<ApiaryListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text('apiary.list.title'.tr())),
      body: const SafeArea(child: _ApiaryListBody()),
    );
  }
}
