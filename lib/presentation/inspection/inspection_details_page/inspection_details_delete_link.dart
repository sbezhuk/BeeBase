part of '../inspection_details_page.dart';

/// A plain destructive text link, not a boxed button — mirrors
/// [_HiveDeleteLink]. Deletion is a rare, deliberate action here, so it
/// stays visually quiet until confirmed, while edit (the common action)
/// lives up in the nav bar instead.
///
/// Deleting an inspection the backend already owns
/// ([Inspection.existsOnServer]) needs the server, so while offline the
/// link is replaced by a note saying so — offering a tappable link there
/// would only lead to a failure. Inspections created offline never reached
/// the server and stay deletable.
final class _InspectionDeleteLink extends StatefulWidget {
  const _InspectionDeleteLink({
    required this.inspection,
    required this.isDeleting,
  });

  final Inspection inspection;
  final bool isDeleting;

  @override
  State<_InspectionDeleteLink> createState() => _InspectionDeleteLinkState();
}

final class _InspectionDeleteLinkState extends State<_InspectionDeleteLink> {
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    if (!di.isRegistered<INetworkInfo>()) return;
    final networkInfo = di<INetworkInfo>();
    unawaited(_resolveConnectivity(networkInfo));
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen(
      _setOnline,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOnline && widget.inspection.existsOnServer) {
      return _buildOfflineNote(context);
    }
    return _buildLink(context);
  }

  Future<void> _resolveConnectivity(INetworkInfo networkInfo) async =>
      _setOnline(await networkInfo.isConnected);

  void _setOnline(bool isOnline) {
    if (!mounted || isOnline == _isOnline) return;
    setState(() => _isOnline = isOnline);
  }

  Widget _buildOfflineNote(BuildContext context) {
    return Center(
      child: Text(
        'inspection.details.delete_offline_blocked'.tr(),
        textAlign: TextAlign.center,
        style: context.textStyles.label.copyWith(
          color: context.colors.honey.muted,
        ),
      ),
    );
  }

  Widget _buildLink(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: GestureDetector(
        onTap: widget.isDeleting ? null : () => _confirmDelete(context),
        child: widget.isDeleting
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(colors.status.error),
                ),
              )
            : Text(
                'inspection.details.delete'.tr(),
                style: context.textStyles.action.copyWith(
                  color: colors.status.error,
                ),
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final cubit = context.read<InspectionDeleteCubit>();
    showConfirmationSheet(
      context: context,
      title: 'inspection.details.delete_confirm_title'.tr(),
      message: 'inspection.details.delete_confirm_message'.tr(),
      confirmLabel: 'inspection.details.delete'.tr(),
      cancelLabel: 'inspection.details.cancel'.tr(),
      icon: Icons.delete_outline,
      onConfirm: cubit.delete,
    );
  }
}
