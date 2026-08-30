import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/hive_sync_status.dart';
import 'package:beebase/presentation/component/honeycomb_pattern.dart';
import 'package:beebase/presentation/hive/cubit/hive_list_cubit/hive_list_cubit.dart';
import 'package:beebase/presentation/hive/widget/hive_sync_badge.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold_action.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

part 'hive_list_page/hive_list_body.dart';
part 'hive_list_page/hive_list_loaded_view.dart';
part 'hive_list_page/hive_list_load_more_error.dart';
part 'hive_list_page/hive_list_tile.dart';
part 'hive_list_page/hive_list_empty_view.dart';
part 'hive_list_page/hive_list_error_view.dart';
part 'hive_list_page/hive_list_retry_button.dart';

/// Lists the hives belonging to one apiary — [apiaryId] is required at
/// construction so a hive is never fetched or shown outside its apiary's
/// context. Reachable only from [ApiaryDetailsPage]. Picks up anything
/// created, edited, or deleted elsewhere via [HiveListCubit]'s subscription
/// to [HiveListRefreshNotifier] rather than by observing navigation —
/// [HiveFormRoute] and [HiveDetailsRoute] are root-level routes, so
/// AutoRoute's `didPopNext` never reaches this page.
@RoutePage()
final class HiveListPage extends StatefulWidget implements AutoRouteWrapper {
  const HiveListPage({required this.apiaryId, required this.apiaryName, super.key});

  final String apiaryId;
  final String apiaryName;

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (_) => di.get<HiveListCubit>(param1: apiaryId)..loadHives(),
      child: this,
    );
  }

  @override
  State<HiveListPage> createState() => _HiveListPageState();
}

final class _HiveListPageState extends State<HiveListPage> {
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
      context.read<HiveListCubit>().loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _createHive() {
    context.router.root.push(HiveFormRoute(apiaryId: widget.apiaryId));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HiveListCubit>();
    return AppScaffold(
      title: widget.apiaryName,
      onRefresh: cubit.refresh,
      trailingAction: AppScaffoldAction(
        label: 'hive.list.addHive'.tr(),
        materialIcon: Icons.add,
        cupertinoIcon: CupertinoIcons.add,
        onPressed: _createHive,
      ),
      slivers: const [_HiveListBody()],
    );
  }
}
