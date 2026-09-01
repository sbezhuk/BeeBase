import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/apiary_sync_status.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_delete_cubit/apiary_delete_cubit.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_details_cubit/apiary_details_cubit.dart';
import 'package:beebase/presentation/apiary/extension/apiary_date_x.dart';
import 'package:beebase/presentation/apiary/widget/apiary_preview_image.dart';
import 'package:beebase/presentation/apiary/widget/apiary_sync_badge.dart';
import 'package:beebase/presentation/connectivity/cubit/connectivity_cubit/connectivity_cubit.dart';
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

part 'apiary_details_page/apiary_details_body.dart';
part 'apiary_details_page/apiary_details_detail_row.dart';
part 'apiary_details_page/apiary_details_delete_link.dart';
part 'apiary_details_page/apiary_details_hives_link.dart';
part 'apiary_details_page/apiary_details_info_section.dart';

@RoutePage()
final class ApiaryDetailsPage extends StatefulWidget implements AutoRouteWrapper {
  const ApiaryDetailsPage({required this.apiary, super.key});

  final Apiary apiary;

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.get<ApiaryDeleteCubit>(param1: apiary)),
        BlocProvider(create: (_) => di.get<ApiaryDetailsCubit>(param1: apiary)..loadHiveCount()),
        BlocProvider(
          create: (_) => di.get<MediaGalleryCubit>(param1: MediaOwnerType.apiary, param2: apiary.id)..load(),
        ),
      ],
      child: this,
    );
  }

  @override
  State<ApiaryDetailsPage> createState() => _ApiaryDetailsPageState();
}

final class _ApiaryDetailsPageState extends State<ApiaryDetailsPage> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApiaryDetailsCubit, ApiaryDetailsState>(
      builder: (context, detailsState) {
        final apiary = detailsState.apiary;
        return AppScaffold(
          title: apiary.name,
          trailingAction: AppScaffoldAction(
            label: 'apiary.details.edit'.tr(),
            materialIcon: Icons.edit_outlined,
            cupertinoIcon: CupertinoIcons.pencil,
            onPressed: _isDeleting ? () {} : () => _edit(context, apiary),
          ),
          slivers: [
            BlocConsumer<ApiaryDeleteCubit, ApiaryDeleteState>(
              listener: _handleStateChange,
              builder: (context, state) {
                _isDeleting = state is ApiaryDeleteLoading;
                return _ApiaryDetailsBody(apiary: apiary, isDeleting: _isDeleting, hiveCount: detailsState.hiveCount);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, Apiary apiary) async {
    final detailsCubit = context.read<ApiaryDetailsCubit>();
    final updated = await context.router.push<Apiary>(ApiaryFormRoute(apiary: apiary));
    if (updated != null) detailsCubit.setApiary(updated);
  }

  void _handleStateChange(BuildContext context, ApiaryDeleteState state) {
    if (state is ApiaryDeleteSuccess) {
      context.router.maybePop(true);
    } else if (state is ApiaryDeleteError) {
      AppSnackBar.show(context, message: state.failure.message.resolve(), variant: AppSnackBarVariant.error);
    }
  }
}
