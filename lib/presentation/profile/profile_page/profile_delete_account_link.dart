part of '../profile_page.dart';

/// A plain destructive text link, matching `_ProfileLogoutLink`'s and
/// `_ApiaryDeleteLink`'s treatment of rare, deliberate destructive actions.
/// Deletion goes through [AccountDeleteCubit] rather than firing and
/// forgetting like logout does, so the loading state can disable the link
/// (preventing a duplicate request) and a failure can be shown without
/// touching the session — the session is only cleared once the backend
/// confirms the account is gone (see `AccountDeleteEmitter.emitDelete`).
///
/// Confirming is two steps: the initial warning sheet, then a second sheet
/// (`showAccountDeleteOtpSheet`) that collects the caller's current TOTP
/// code — required since the backend never deletes an account without one
/// (see `IAccountDeleter.deleteAccount`). Cancelling either step leaves the
/// account untouched; the cubit's own delete call only fires once a
/// format-valid code has actually been entered.
final class _ProfileDeleteAccountLink extends StatelessWidget {
  const _ProfileDeleteAccountLink();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocConsumer<AccountDeleteCubit, AccountDeleteState>(
      listener: (context, state) {
        if (state is AccountDeleteError) {
          AppSnackBar.show(
            context,
            message: state.failure.message.resolve(),
            variant: AppSnackBarVariant.error,
          );
        }
      },
      builder: (context, state) {
        final isDeleting = state is AccountDeleteLoading;
        return Center(
          child: GestureDetector(
            onTap: isDeleting ? null : () => _confirmDelete(context),
            child: isDeleting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(colors.status.error),
                    ),
                  )
                : Text(
                    'profile.page.delete_account'.tr(),
                    style: context.textStyles.action.copyWith(
                      color: colors.status.error,
                    ),
                  ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    final cubit = context.read<AccountDeleteCubit>();
    showConfirmationSheet(
      context: context,
      title: 'profile.page.delete_account_confirm_title'.tr(),
      message: 'profile.page.delete_account_confirm_message'.tr(),
      confirmLabel: 'profile.page.delete_account'.tr(),
      cancelLabel: 'profile.page.delete_account_cancel'.tr(),
      icon: Icons.delete_forever_outlined,
      onConfirm: () => _confirmWithOtp(context, cubit),
    );
  }

  Future<void> _confirmWithOtp(BuildContext context, AccountDeleteCubit cubit) async {
    final otp = await showAccountDeleteOtpSheet(context);
    if (otp == null) return;
    await cubit.delete(otp: otp);
  }
}
