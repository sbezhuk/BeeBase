import 'package:auto_route/auto_route.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/text_field/app_text_field.dart';
import 'package:beebase/presentation/profile/avatar_image_resolver.dart';
import 'package:beebase/presentation/profile/cubit/profile_edit_cubit/profile_edit_cubit.dart';
import 'package:beebase/presentation/profile/widget/profile_avatar.dart';
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
import 'package:image_picker/image_picker.dart';

part 'profile_edit_page/profile_edit_content.dart';
part 'profile_edit_page/profile_edit_avatar_picker.dart';
part 'profile_edit_page/profile_edit_avatar_picker_sheet.dart';
part 'profile_edit_page/profile_edit_submit_button.dart';

@RoutePage()
final class ProfileEditPage extends StatefulWidget implements AutoRouteWrapper {
  const ProfileEditPage({required this.user, super.key});

  final User user;

  @override
  Widget wrappedRoute(BuildContext context) {
    return BlocProvider(create: (_) => di.get<ProfileEditCubit>(), child: this);
  }

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

final class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final _firstNameController = TextEditingController(
    text: widget.user.firstName,
  );
  late final _lastNameController = TextEditingController(
    text: widget.user.lastName,
  );
  final _picker = ImagePicker();
  late final _resolver = di<AvatarImageResolver>();

  String? _pendingAvatarLocalFilePath;
  bool _avatarRemoved = false;

  String? get _displayedAvatarId =>
      _avatarRemoved ? null : widget.user.avatarId;

  String? get _displayedAvatarLocalPath =>
      _avatarRemoved ? null : _pendingAvatarLocalFilePath;

  bool get _canRemoveAvatar =>
      _displayedAvatarId != null || _pendingAvatarLocalFilePath != null;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pendingAvatarLocalFilePath = picked.path;
      _avatarRemoved = false;
    });
  }

  void _removeAvatar() {
    setState(() {
      _pendingAvatarLocalFilePath = null;
      _avatarRemoved = true;
    });
  }

  void _showAvatarSheet() {
    _showProfileAvatarPickerSheet(
      context: context,
      onTakePhoto: () => _pickAvatar(ImageSource.camera),
      onPickFromGallery: () => _pickAvatar(ImageSource.gallery),
      onRemove: _canRemoveAvatar ? _removeAvatar : null,
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ProfileEditCubit>().submit(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        newAvatarLocalFilePath: _pendingAvatarLocalFilePath,
        removeAvatar: _avatarRemoved,
      );
    }
  }

  void _handleStateChange(BuildContext context, ProfileEditState state) {
    if (state is ProfileEditSuccess) {
      context.router.maybePop();
    } else if (state is ProfileEditError) {
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
      title: 'profile.edit.title'.tr(),
      fadeEdges: true,
      slivers: [
        BlocListener<ProfileEditCubit, ProfileEditState>(
          listener: _handleStateChange,
          child: SliverPadding(
            padding: EdgeInsets.all(context.spacing.md),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: _ProfileEditContent(
                  firstNameController: _firstNameController,
                  lastNameController: _lastNameController,
                  avatarId: _displayedAvatarId,
                  avatarLocalFilePath: _displayedAvatarLocalPath,
                  resolver: _resolver,
                  onAvatarTap: _showAvatarSheet,
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
