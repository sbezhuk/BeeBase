import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_form_cubit/apiary_form_cubit.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'apiary_form_page/apiary_form_content.dart';
part 'apiary_form_page/apiary_form_field.dart';
part 'apiary_form_page/apiary_form_submit_button.dart';

@RoutePage()
final class ApiaryFormPage extends StatefulWidget implements AutoRouteWrapper {
  const ApiaryFormPage({this.apiary, super.key});

  final Apiary? apiary;

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (_) => di.get<ApiaryFormCubit>(param1: apiary),
      child: this,
    );
  }

  @override
  State<ApiaryFormPage> createState() => _ApiaryFormPageState();
}

final class _ApiaryFormPageState extends State<ApiaryFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.apiary?.name);
  late final _descriptionController = TextEditingController(
    text: widget.apiary?.description,
  );
  late final _locationController = TextEditingController(
    text: widget.apiary?.location,
  );

  bool get _isEditing => widget.apiary != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final description = _descriptionController.text.trim();
      final location = _locationController.text.trim();
      context.read<ApiaryFormCubit>().submit(
        name: _nameController.text.trim(),
        description: description.isEmpty ? null : description,
        location: location.isEmpty ? null : location,
      );
    }
  }

  void _handleStateChange(BuildContext context, ApiaryFormState state) {
    if (state is ApiaryFormSuccess) {
      context.router.pop(state.apiary);
    } else if (state is ApiaryFormError) {
      AppSnackBar.show(
        context,
        message: state.failure.message.resolve(),
        variant: AppSnackBarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'apiary.form.editTitle'.tr()
              : 'apiary.form.createTitle'.tr(),
        ),
      ),
      body: SafeArea(
        child: BlocListener<ApiaryFormCubit, ApiaryFormState>(
          listener: _handleStateChange,
          child: Padding(
            padding: EdgeInsets.all(context.spacing.lg),
            child: Form(
              key: _formKey,
              child: _ApiaryFormContent(
                nameController: _nameController,
                descriptionController: _descriptionController,
                locationController: _locationController,
                isEditing: _isEditing,
                onSubmit: _submit,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
