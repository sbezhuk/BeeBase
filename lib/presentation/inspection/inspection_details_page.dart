import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/enum/sync_status.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_delete_cubit/inspection_delete_cubit.dart';
import 'package:beebase/presentation/inspection/extension/inspection_date_x.dart';
import 'package:beebase/presentation/inspection/extension/inspection_type_x.dart';
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

part 'inspection_details_page/inspection_details_body.dart';
part 'inspection_details_page/inspection_details_detail_row.dart';
part 'inspection_details_page/inspection_details_delete_link.dart';
part 'inspection_details_page/inspection_details_info_section.dart';

@RoutePage()
final class InspectionDetailsPage extends StatefulWidget implements AutoRouteWrapper {
  const InspectionDetailsPage({required this.inspection, super.key});

  final Inspection inspection;

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.get<InspectionDeleteCubit>(param1: inspection)),
        BlocProvider(
          create: (_) => di.get<MediaGalleryCubit>(param1: MediaOwnerType.inspection, param2: inspection.id)..load(),
        ),
      ],
      child: this,
    );
  }

  @override
  State<InspectionDetailsPage> createState() => _InspectionDetailsPageState();
}

final class _InspectionDetailsPageState extends State<InspectionDetailsPage> {
  late Inspection _inspection = widget.inspection;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _inspection.date.toInspectionDisplayDate(),
      fadeEdges: true,
      trailingAction: AppScaffoldAction(
        label: 'inspection.details.edit'.tr(),
        materialIcon: Icons.edit_outlined,
        cupertinoIcon: CupertinoIcons.pencil,
        onPressed: _isDeleting ? () {} : () => _edit(context),
      ),
      slivers: [
        BlocConsumer<InspectionDeleteCubit, InspectionDeleteState>(
          listener: _handleStateChange,
          builder: (context, state) {
            _isDeleting = state is InspectionDeleteLoading;
            return _InspectionDetailsBody(inspection: _inspection, isDeleting: _isDeleting);
          },
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context) async {
    // If the inspection has unsynchronized local changes, block online
    // editing to prevent accidentally overwriting the pending local data.
    // Offline users can always edit — the guard only fires when
    // connectivity is available.
    if (_inspection.syncStatus.isPending) {
      final networkInfo = di.get<INetworkInfo>();
      final isOnline = await networkInfo.isConnected;
      if (isOnline && context.mounted) {
        _showSyncBlockedDialog(context);
        return;
      }
    }
    if (!context.mounted) return;
    final updated = await context.router.push<Inspection>(
      InspectionFormRoute(hiveId: _inspection.hiveId, inspection: _inspection),
    );
    if (updated != null && mounted) setState(() => _inspection = updated);
  }

  void _showSyncBlockedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('inspection.sync_blocked_title'.tr()),
        content: Text('inspection.sync_blocked_message'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('inspection.sync_blocked_action'.tr())),
        ],
      ),
    );
  }

  void _handleStateChange(BuildContext context, InspectionDeleteState state) {
    if (state is InspectionDeleteSuccess) {
      context.router.maybePop(true);
    } else if (state is InspectionDeleteError) {
      AppSnackBar.show(context, message: state.failure.message.resolve(), variant: AppSnackBarVariant.error);
    }
  }
}
