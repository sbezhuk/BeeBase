import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/local/inspection_sync_status.dart';
import 'package:beebase/presentation/connectivity/cubit/connectivity_cubit/connectivity_cubit.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_delete_cubit/inspection_delete_cubit.dart';
import 'package:beebase/presentation/inspection/extension/inspection_date_x.dart';
import 'package:beebase/presentation/inspection/extension/inspection_type_x.dart';
import 'package:beebase/presentation/inspection/widget/inspection_sync_badge.dart';
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
    return BlocProvider(
      create: (_) => di.get<InspectionDeleteCubit>(param1: inspection),
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
    final updated = await context.router.push<Inspection>(
      InspectionFormRoute(hiveId: _inspection.hiveId, inspection: _inspection),
    );
    if (updated != null && mounted) setState(() => _inspection = updated);
  }

  void _handleStateChange(BuildContext context, InspectionDeleteState state) {
    if (state is InspectionDeleteSuccess) {
      context.router.maybePop(true);
    } else if (state is InspectionDeleteError) {
      AppSnackBar.show(
        context,
        message: state.failure.message.resolve(),
        variant: AppSnackBarVariant.error,
      );
    }
  }
}
