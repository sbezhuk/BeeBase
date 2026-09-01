import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/media_owner_type.dart';
import 'package:beebase/presentation/apiary/cubit/apiary_form_cubit/apiary_form_cubit.dart';
import 'package:beebase/presentation/apiary/widget/apiary_section_card.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/font.dart';
import 'package:beebase/presentation/component/text_field/app_text_field.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/media/widget/media_gallery_section.dart';
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

part 'apiary_form_page/apiary_form_content.dart';
part 'apiary_form_page/apiary_form_submit_button.dart';
part 'apiary_form_page/apiary_location_primary_action.dart';
part 'apiary_form_page/apiary_location_section.dart';

@RoutePage()
final class ApiaryFormPage extends StatefulWidget implements AutoRouteWrapper {
  const ApiaryFormPage({this.apiary, super.key});

  final Apiary? apiary;

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.get<ApiaryFormCubit>(param1: apiary)),
        BlocProvider(
          create: (_) => di.get<MediaGalleryCubit>(param1: MediaOwnerType.apiary, param2: apiary?.id)..load(),
        ),
      ],
      child: this,
    );
  }

  @override
  State<ApiaryFormPage> createState() => _ApiaryFormPageState();
}

final class _ApiaryFormPageState extends State<ApiaryFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.apiary?.name);
  late final _descriptionController = TextEditingController(text: widget.apiary?.description);
  bool _isFetchingLocation = false;

  /// The resolved address and coordinates, geolocation-only — there's no
  /// manual location input, so these are only ever set by
  /// [_useCurrentLocation]. Seeded from the apiary being edited, if any.
  String? _locationAddress;
  double? _latitude;
  double? _longitude;

  bool get _isEditing => widget.apiary != null;

  @override
  void initState() {
    super.initState();
    _locationAddress = widget.apiary?.location;
    _latitude = widget.apiary?.lat;
    _longitude = widget.apiary?.lon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final description = _descriptionController.text.trim();
      context.read<ApiaryFormCubit>().submit(
        name: _nameController.text.trim(),
        description: description.isEmpty ? null : description,
        location: _locationAddress,
        lat: _latitude,
        lon: _longitude,
        mediaGalleryCubit: context.read<MediaGalleryCubit>(),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    final cubit = context.read<ApiaryFormCubit>();
    setState(() => _isFetchingLocation = true);

    final result = await cubit.resolveCurrentLocation();
    if (!mounted) return;

    result.fold((failure) => AppSnackBar.show(context, message: failure.messageKey.tr(), variant: AppSnackBarVariant.error), (
      location,
    ) {
      _locationAddress = location.address;
      _latitude = location.latitude;
      _longitude = location.longitude;
    });
    setState(() => _isFetchingLocation = false);
  }

  void _handleStateChange(BuildContext context, ApiaryFormState state) {
    if (state is ApiaryFormSuccess) {
      context.router.pop(state.apiary);
    } else if (state is ApiaryFormError) {
      AppSnackBar.show(context, message: state.failure.message.resolve(), variant: AppSnackBarVariant.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEditing ? 'apiary.form.editTitle'.tr() : 'apiary.form.createTitle'.tr(),
      fadeEdges: true,
      slivers: [
        BlocListener<ApiaryFormCubit, ApiaryFormState>(
          listener: _handleStateChange,
          child: SliverPadding(
            padding: EdgeInsets.all(context.spacing.md),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: _ApiaryFormContent(
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                  locationAddress: _locationAddress,
                  latitude: _latitude,
                  longitude: _longitude,
                  isEditing: _isEditing,
                  isFetchingLocation: _isFetchingLocation,
                  onSubmit: _submit,
                  onUseCurrentLocation: _useCurrentLocation,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
