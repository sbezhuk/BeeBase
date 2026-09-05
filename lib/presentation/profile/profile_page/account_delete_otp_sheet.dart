part of '../profile_page.dart';

/// Shows [_AccountDeleteOtpSheet] as a modal bottom sheet, resolving to the
/// entered (already format-validated) TOTP code once the user submits, or
/// null if they cancel. Presented as the second step of account deletion,
/// right after the user confirms the initial warning sheet — see
/// `_ProfileDeleteAccountLink`, which is the only caller.
Future<String?> showAccountDeleteOtpSheet(BuildContext context) {
  return showAppBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _AccountDeleteOtpSheet(),
  );
}

/// Content of the account-deletion OTP sheet: the same icon+title+message
/// rhythm as [ConfirmationSheet], with an [OtpInputField] in place of the
/// plain message, then a Delete/Cancel button pair. Deliberately collects
/// and format-validates the code only — it doesn't call the backend itself,
/// so it has no cubit dependency of its own; the caller submits the actual
/// `deleteAccount` request once this resolves (see
/// `_ProfileDeleteAccountLink`), reusing that flow's own loading/error
/// handling rather than duplicating it here.
final class _AccountDeleteOtpSheet extends StatefulWidget {
  const _AccountDeleteOtpSheet();

  @override
  State<_AccountDeleteOtpSheet> createState() => _AccountDeleteOtpSheetState();
}

final class _AccountDeleteOtpSheetState extends State<_AccountDeleteOtpSheet> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    if (value == null || !RegExp(r'^[0-9]{6}$').hasMatch(value)) {
      return 'profile.page.delete_account_otp.validations.otp_invalid_format'
          .tr();
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_otpController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final spacing = context.spacing;

    return AppBottomSheetCard(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.status.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever_outlined,
                color: colors.status.error,
                size: 26,
              ),
            ),
            SizedBox(height: spacing.md),
            Text(
              'profile.page.delete_account_otp.title'.tr(),
              textAlign: TextAlign.center,
              style: textStyles.title.copyWith(fontSize: 20),
            ),
            SizedBox(height: spacing.xs),
            Text(
              'profile.page.delete_account_otp.message'.tr(),
              textAlign: TextAlign.center,
              style: textStyles.body.copyWith(color: colors.text.secondary),
            ),
            SizedBox(height: spacing.lg),
            OtpInputField(
              controller: _otpController,
              label: 'profile.page.delete_account_otp.otp_label'.tr(),
              autofocus: true,
              validator: _validate,
            ),
            SizedBox(height: spacing.lg),
            AppSheetButton(
              label: 'profile.page.delete_account'.tr(),
              filled: true,
              color: colors.status.error,
              onPressed: _submit,
            ),
            SizedBox(height: spacing.sm),
            AppSheetButton(
              label: 'profile.page.delete_account_cancel'.tr(),
              filled: false,
              color: colors.text.primary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
