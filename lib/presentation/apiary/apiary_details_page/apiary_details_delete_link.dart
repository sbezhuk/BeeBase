part of '../apiary_details_page.dart';

/// A plain destructive text link, not a boxed button — deletion is a rare,
/// deliberate action here, so it stays visually quiet until confirmed,
/// while edit (the common action) lives up in the nav bar instead.
///
/// Deleting an apiary the backend already owns ([Apiary.existsOnServer])
/// needs the server, so while offline the link is replaced by a note saying
/// so — offering a tappable link there would only lead to a failure. Apiaries
/// created offline never reached the server and stay deletable.
final class _ApiaryDeleteLink extends StatefulWidget {
  const _ApiaryDeleteLink({required this.apiary, required this.isDeleting});

  final Apiary apiary;
  final bool isDeleting;

  @override
  State<_ApiaryDeleteLink> createState() => _ApiaryDeleteLinkState();
}

final class _ApiaryDeleteLinkState extends State<_ApiaryDeleteLink> {
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    if (!di.isRegistered<INetworkInfo>()) return;
    final networkInfo = di<INetworkInfo>();
    unawaited(_resolveConnectivity(networkInfo));
    _connectivitySubscription = networkInfo.onConnectivityChanged.listen(_setOnline);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOnline && widget.apiary.existsOnServer) return _buildOfflineNote(context);
    return _buildLink(context);
  }

  Future<void> _resolveConnectivity(INetworkInfo networkInfo) async => _setOnline(await networkInfo.isConnected);

  void _setOnline(bool isOnline) {
    if (!mounted || isOnline == _isOnline) return;
    setState(() => _isOnline = isOnline);
  }

  Widget _buildOfflineNote(BuildContext context) {
    return Center(
      child: Text(
        'apiary.details.delete_offline_blocked'.tr(),
        textAlign: TextAlign.center,
        style: context.textStyles.label.copyWith(color: context.colors.honey.muted),
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
            : Text('apiary.details.delete'.tr(), style: context.textStyles.action.copyWith(color: colors.status.error)),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final cubit = context.read<ApiaryDeleteCubit>();
    showConfirmationSheet(
      context: context,
      title: 'apiary.details.delete_confirm_title'.tr(),
      message: 'apiary.details.delete_confirm_message'.tr(),
      confirmLabel: 'apiary.details.delete'.tr(),
      cancelLabel: 'apiary.details.cancel'.tr(),
      icon: Icons.delete_outline,
      onConfirm: cubit.delete,
    );
  }
}
