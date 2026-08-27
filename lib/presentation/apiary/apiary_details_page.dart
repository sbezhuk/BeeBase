import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_delete_cubit/apiary_delete_cubit.dart';
import 'package:beebase/presentation/apiary/extension/apiary_date_x.dart';
import 'package:beebase/presentation/apiary/widget/apiary_scaffold.dart';
import 'package:beebase/presentation/apiary/widget/apiary_scaffold_action.dart';
import 'package:beebase/presentation/apiary/widget/apiary_section_card.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

part 'apiary_details_page/apiary_details_body.dart';
part 'apiary_details_page/apiary_details_detail_row.dart';
part 'apiary_details_page/apiary_details_delete_link.dart';

@RoutePage()
final class ApiaryDetailsPage extends StatefulWidget implements AutoRouteWrapper {
  const ApiaryDetailsPage({required this.apiary, super.key});

  final Apiary apiary;

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (_) => di.get<ApiaryDeleteCubit>(param1: apiary),
      child: this,
    );
  }

  @override
  State<ApiaryDetailsPage> createState() => _ApiaryDetailsPageState();
}

final class _ApiaryDetailsPageState extends State<ApiaryDetailsPage> {
  late Apiary _apiary = widget.apiary;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return ApiaryScaffold(
      title: _apiary.name,
      trailingAction: ApiaryScaffoldAction(
        label: 'apiary.details.edit'.tr(),
        materialIcon: Icons.edit_outlined,
        cupertinoIcon: CupertinoIcons.pencil,
        onPressed: _isDeleting ? () {} : () => _edit(context),
      ),
      body: BlocConsumer<ApiaryDeleteCubit, ApiaryDeleteState>(
        listener: _handleStateChange,
        builder: (context, state) {
          _isDeleting = state is ApiaryDeleteLoading;
          return _ApiaryDetailsBody(apiary: _apiary, isDeleting: _isDeleting);
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await context.router.push<Apiary>(ApiaryFormRoute(apiary: _apiary));
    if (updated != null && mounted) setState(() => _apiary = updated);
  }

  void _handleStateChange(BuildContext context, ApiaryDeleteState state) {
    if (state is ApiaryDeleteSuccess) {
      context.router.maybePop(true);
    } else if (state is ApiaryDeleteError) {
      AppSnackBar.show(context, message: state.failure.message.resolve(), variant: AppSnackBarVariant.error);
    }
  }
}
