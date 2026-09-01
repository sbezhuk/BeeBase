import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/text_field/app_text_field.dart';
import 'package:beebase/presentation/hive/cubit/hive_form_cubit/hive_form_cubit.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/media/widget/media_gallery_section.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'hive_form_page/hive_form_content.dart';
part 'hive_form_page/hive_form_submit_button.dart';

/// Creates or edits a hive within [apiaryId]'s scope — required at
/// construction (even when editing, via [hive]) so a hive is never created
/// or saved outside its apiary's context.
@RoutePage()
final class HiveFormPage extends StatefulWidget implements AutoRouteWrapper {
  const HiveFormPage({required this.apiaryId, this.hive, super.key});

  final String apiaryId;
  final Hive? hive;

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => di.get<HiveFormCubit>(param1: apiaryId, param2: hive),
        ),
        BlocProvider(
          create: (_) => di.get<MediaGalleryCubit>(param1: MediaOwnerType.hive, param2: hive?.id)..load(),
        ),
      ],
      child: this,
    );
  }

  @override
  State<HiveFormPage> createState() => _HiveFormPageState();
}

final class _HiveFormPageState extends State<HiveFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.hive?.name);
  late final _descriptionController = TextEditingController(text: widget.hive?.notes);

  bool get _isEditing => widget.hive != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final description = _descriptionController.text.trim();
      context.read<HiveFormCubit>().submit(
        name: _nameController.text.trim(),
        description: description.isEmpty ? null : description,
        mediaGalleryCubit: context.read<MediaGalleryCubit>(),
      );
    }
  }

  void _handleStateChange(BuildContext context, HiveFormState state) {
    if (state is HiveFormSuccess) {
      context.router.pop(state.hive);
    } else if (state is HiveFormError) {
      AppSnackBar.show(context, message: state.failure.message.resolve(), variant: AppSnackBarVariant.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEditing ? 'hive.form.editTitle'.tr() : 'hive.form.createTitle'.tr(),
      fadeEdges: true,
      slivers: [
        BlocListener<HiveFormCubit, HiveFormState>(
          listener: _handleStateChange,
          child: SliverPadding(
            padding: EdgeInsets.all(context.spacing.md),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: _HiveFormContent(
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                  isEditing: _isEditing,
                  onSubmit: _submit,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
