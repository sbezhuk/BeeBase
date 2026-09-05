import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/presentation/component/honeycomb_pattern.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_list_cubit/inspection_list_cubit.dart';
import 'package:beebase/presentation/inspection/extension/inspection_date_x.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold_action.dart';
import 'package:beebase/presentation/widgets/loading_overlay/loading_overlay.dart';
import 'package:beebase/presentation/widgets/retry_button/retry_button.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'inspection_list_page/inspection_list_body.dart';
part 'inspection_list_page/inspection_list_loaded_view.dart';
part 'inspection_list_page/inspection_list_load_more_error.dart';
part 'inspection_list_page/inspection_list_tile.dart';
part 'inspection_list_page/inspection_list_empty_view.dart';
part 'inspection_list_page/inspection_list_error_view.dart';

/// Lists the inspections belonging to one hive — [hiveId] is required at
/// construction so an inspection is never fetched or shown outside its
/// hive's context. Reachable only from [HiveDetailsPage]. Picks up anything
/// created, edited, or deleted elsewhere via [InspectionListCubit]'s
/// subscription to [InspectionListRefreshNotifier] rather than by observing
/// navigation — [InspectionFormRoute] and [InspectionDetailsRoute] are
/// root-level routes, so AutoRoute's `didPopNext` never reaches this page.
@RoutePage()
final class InspectionListPage extends StatefulWidget
    implements AutoRouteWrapper {
  const InspectionListPage({
    required this.hiveId,
    required this.hiveName,
    super.key,
  });

  final String hiveId;
  final String hiveName;

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          di.get<InspectionListCubit>(param1: hiveId)..loadInspections(),
      child: this,
    );
  }

  @override
  State<InspectionListPage> createState() => _InspectionListPageState();
}

final class _InspectionListPageState extends State<InspectionListPage> {
  // How close to the bottom (in logical pixels) the user needs to scroll
  // before the next page is requested — a scroll-behavior heuristic, not a
  // themed visual dimension, so it isn't sourced from context.spacing.
  static const double _loadMoreThreshold = 300;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      context.read<InspectionListCubit>().loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _createInspection() {
    context.router.root.push(InspectionFormRoute(hiveId: widget.hiveId));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InspectionListCubit>();
    return BlocSelector<InspectionListCubit, InspectionListState, bool>(
      selector: (state) =>
          state is InspectionListLoading ||
          (state is InspectionListLoaded && state.isRefreshing),
      builder: (context, isLoading) {
        return LoadingOverlay(
          isLoading: isLoading,
          child: AppScaffold(
            title: widget.hiveName,
            onRefresh: cubit.refresh,
            fadeEdges: true,
            trailingAction: AppScaffoldAction(
              label: 'inspection.list.add_inspection'.tr(),
              materialIcon: Icons.add,
              cupertinoIcon: CupertinoIcons.add,
              onPressed: _createInspection,
            ),
            slivers: const [_InspectionListBody()],
          ),
        );
      },
    );
  }
}
