import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_delete_cubit/apiary_delete_cubit.dart';
import 'package:beebase/presentation/router/app_router.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'apiary_details_page/apiary_details_body.dart';
part 'apiary_details_page/apiary_details_detail_row.dart';
part 'apiary_details_page/apiary_details_actions.dart';

@RoutePage()
final class ApiaryDetailsPage extends StatefulWidget
    implements AutoRouteWrapper {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text('apiary.details.title'.tr())),
      body: SafeArea(
        child: BlocConsumer<ApiaryDeleteCubit, ApiaryDeleteState>(
          listener: _handleStateChange,
          builder: (context, state) => _ApiaryDetailsBody(
            apiary: _apiary,
            isDeleting: state is ApiaryDeleteLoading,
            onEdited: (updated) => setState(() => _apiary = updated),
          ),
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, ApiaryDeleteState state) {
    if (state is ApiaryDeleteSuccess) {
      context.router.maybePop(true);
    } else if (state is ApiaryDeleteError) {
      AppSnackBar.show(
        context,
        message: state.failure.message.resolve(),
        variant: AppSnackBarVariant.error,
      );
    }
  }
}
