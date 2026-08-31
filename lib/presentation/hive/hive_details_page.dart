import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/hive_sync_status.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/presentation/connectivity/cubit/connectivity_cubit/connectivity_cubit.dart';
import 'package:beebase/presentation/hive/cubit/hive_delete_cubit/hive_delete_cubit.dart';
import 'package:beebase/presentation/hive/extension/hive_date_x.dart';
import 'package:beebase/presentation/hive/widget/hive_sync_badge.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/media/widget/media_gallery_section.dart';
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

part 'hive_details_page/hive_details_body.dart';
part 'hive_details_page/hive_details_detail_row.dart';
part 'hive_details_page/hive_details_delete_link.dart';
part 'hive_details_page/hive_details_info_section.dart';

@RoutePage()
final class HiveDetailsPage extends StatefulWidget implements AutoRouteWrapper {
  const HiveDetailsPage({required this.hive, super.key});

  final Hive hive;

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.get<HiveDeleteCubit>(param1: hive)),
        BlocProvider(
          create: (_) => di.get<MediaGalleryCubit>(param1: MediaOwnerType.hive, param2: hive.id)..load(),
        ),
      ],
      child: this,
    );
  }

  @override
  State<HiveDetailsPage> createState() => _HiveDetailsPageState();
}

final class _HiveDetailsPageState extends State<HiveDetailsPage> {
  late Hive _hive = widget.hive;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _hive.name,
      trailingAction: AppScaffoldAction(
        label: 'hive.details.edit'.tr(),
        materialIcon: Icons.edit_outlined,
        cupertinoIcon: CupertinoIcons.pencil,
        onPressed: _isDeleting ? () {} : () => _edit(context),
      ),
      slivers: [
        BlocConsumer<HiveDeleteCubit, HiveDeleteState>(
          listener: _handleStateChange,
          builder: (context, state) {
            _isDeleting = state is HiveDeleteLoading;
            return _HiveDetailsBody(hive: _hive, isDeleting: _isDeleting);
          },
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await context.router.push<Hive>(HiveFormRoute(apiaryId: _hive.apiaryId, hive: _hive));
    if (updated != null && mounted) setState(() => _hive = updated);
  }

  void _handleStateChange(BuildContext context, HiveDeleteState state) {
    if (state is HiveDeleteSuccess) {
      context.router.maybePop(true);
    } else if (state is HiveDeleteError) {
      AppSnackBar.show(context, message: state.failure.message.resolve(), variant: AppSnackBarVariant.error);
    }
  }
}
