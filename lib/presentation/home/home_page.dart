import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/activity_item.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/entity/apiary_stats.dart';
import 'package:beebase/domain/entity/dashboard_overview.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/entity/inspection_stats.dart';
import 'package:beebase/presentation/home/cubit/dashboard_cubit/dashboard_cubit.dart';
import 'package:beebase/presentation/home/extension/dashboard_date_x.dart';
import 'package:beebase/presentation/home/home_page/dashboard_section_card.dart';
import 'package:beebase/presentation/home/home_page/dashboard_stat_tile.dart';
import 'package:beebase/presentation/home/home_page/hive_distribution_chart.dart';
import 'package:beebase/presentation/home/home_page/inspection_activity_chart.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold.dart';
import 'package:beebase/presentation/widgets/loading_overlay/loading_overlay.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/either.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

part 'home_page/dashboard_apiary_stats_section.dart';
part 'home_page/dashboard_body.dart';
part 'home_page/dashboard_empty_view.dart';
part 'home_page/dashboard_inspection_stats_section.dart';
part 'home_page/dashboard_offline_view.dart';
part 'home_page/dashboard_overview_section.dart';
part 'home_page/dashboard_recent_activity_section.dart';
part 'home_page/dashboard_section_error.dart';
part 'home_page/dashboard_section_loading.dart';
part 'home_page/dashboard_section_switcher.dart';
part 'home_page/dashboard_tappable_tile.dart';

/// The app's Home tab — the online-only Dashboard (BEEB-24). Provides
/// [DashboardCubit] and reflects its state; a network fetch happens on
/// every open (never from a local cache) and again on pull-to-refresh.
@RoutePage()
final class HomePage extends StatelessWidget implements AutoRouteWrapper {
  const HomePage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (_) => di.get<DashboardCubit>()..loadDashboard(),
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return switch (state) {
          DashboardLoading() => LoadingOverlay(
            isLoading: true,
            child: AppScaffold(
              title: 'dashboard.title'.tr(),
              showBackButton: false,
              slivers: const [],
            ),
          ),
          DashboardOffline() => _DashboardOfflineView(
            onRetry: context.read<DashboardCubit>().retry,
          ),
          final DashboardLoaded loaded => LoadingOverlay(
            isLoading: loaded.isRefreshing,
            child: AppScaffold(
              title: 'dashboard.title'.tr(),
              showBackButton: false,
              fadeEdges: true,
              onRefresh: context.read<DashboardCubit>().refresh,
              slivers: [_DashboardBody(state: loaded)],
            ),
          ),
        };
      },
    );
  }
}
