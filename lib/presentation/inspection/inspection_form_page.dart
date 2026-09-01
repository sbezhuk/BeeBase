import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/inspection_type.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/text_field/app_text_field.dart';
import 'package:beebase/presentation/inspection/cubit/inspection_form_cubit/inspection_form_cubit.dart';
import 'package:beebase/presentation/inspection/extension/inspection_date_x.dart';
import 'package:beebase/presentation/inspection/extension/inspection_type_x.dart';
import 'package:beebase/presentation/widgets/app_scaffold/app_scaffold.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'inspection_form_page/inspection_form_content.dart';
part 'inspection_form_page/inspection_form_date_field.dart';
part 'inspection_form_page/inspection_form_type_field.dart';
part 'inspection_form_page/inspection_form_submit_button.dart';

/// Creates or edits an inspection within [hiveId]'s scope — required at
/// construction (even when editing, via [inspection]) so an inspection is
/// never created or saved outside its hive's context.
@RoutePage()
final class InspectionFormPage extends StatefulWidget implements AutoRouteWrapper {
  const InspectionFormPage({required this.hiveId, this.inspection, super.key});

  final String hiveId;
  final Inspection? inspection;

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(
      create: (_) => di.get<InspectionFormCubit>(param1: hiveId, param2: inspection),
      child: this,
    );
  }

  @override
  State<InspectionFormPage> createState() => _InspectionFormPageState();
}

final class _InspectionFormPageState extends State<InspectionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _notesController = TextEditingController(text: widget.inspection?.notes);

  // Defaults to today, per BEEB-7's acceptance criteria ("new inspection
  // defaults to current date") — never null, so there's nothing to validate.
  late DateTime _selectedDate = widget.inspection?.date ?? DateTime.now();

  late InspectionType _selectedType = widget.inspection?.type ?? InspectionType.routine;

  bool get _isEditing => widget.inspection != null;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final notes = _notesController.text.trim();
      context.read<InspectionFormCubit>().submit(
        date: _selectedDate,
        type: _selectedType,
        notes: notes.isEmpty ? null : notes,
      );
    }
  }

  void _handleStateChange(BuildContext context, InspectionFormState state) {
    if (state is InspectionFormSuccess) {
      context.router.pop(state.inspection);
    } else if (state is InspectionFormError) {
      AppSnackBar.show(
        context,
        message: state.failure.message.resolve(),
        variant: AppSnackBarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEditing ? 'inspection.form.edit_title'.tr() : 'inspection.form.create_title'.tr(),
      fadeEdges: true,
      slivers: [
        BlocListener<InspectionFormCubit, InspectionFormState>(
          listener: _handleStateChange,
          child: SliverPadding(
            padding: EdgeInsets.all(context.spacing.md),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: _InspectionFormContent(
                  selectedDate: _selectedDate,
                  selectedType: _selectedType,
                  notesController: _notesController,
                  isEditing: _isEditing,
                  onPickDate: _pickDate,
                  onSelectType: (type) => setState(() => _selectedType = type),
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
