import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/local/apiary_sync_status.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_list_cubit/apiary_list_cubit.dart';
import 'package:beebase/presentation/apiary/extension/apiary_date_x.dart';
import 'package:beebase/presentation/apiary/widget/apiary_hexagon_badge.dart';
import 'package:beebase/presentation/apiary/widget/apiary_preview_image.dart';
import 'package:beebase/presentation/apiary/widget/apiary_sync_badge.dart';
import 'package:beebase/presentation/component/honeycomb_pattern.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

part 'apiary_list_page/apiary_list_body.dart';
part 'apiary_list_page/apiary_list_loaded_view.dart';
part 'apiary_list_page/apiary_list_load_more_error.dart';
part 'apiary_list_page/apiary_list_tile.dart';
part 'apiary_list_page/apiary_list_stat.dart';
part 'apiary_list_page/apiary_list_empty_view.dart';
part 'apiary_list_page/apiary_list_error_view.dart';
part 'apiary_list_page/apiary_list_retry_button.dart';

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
    return BlocProvider(create: (_) => di.get<ApiaryListCubit>()..loadApiaries(), child: this);
  }

  @override
  State<ApiaryListPage> createState() => _ApiaryListPageState();
}

final class _ApiaryListPageState extends State<ApiaryListPage> {
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
      context.read<ApiaryListCubit>().loadNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ApiaryListCubit>();
    return AppScaffold(
      title: 'apiary.list.title'.tr(),
      showBackButton: false,
      onRefresh: cubit.refresh,
      fadeEdges: true,
      controller: _scrollController,
      slivers: const [_ApiaryListBody()],
    );
  }
}
