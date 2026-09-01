import 'package:beebase/presentation/connectivity/cubit/connectivity_cubit/connectivity_cubit.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide connectivity notifications — mounted inside the main tab shell
/// alongside [OfflineSyncBanner] (not the pre-auth screens). Renders nothing
/// itself: it's purely a [ConnectivityCubit] listener that drives the shared
/// [AppSnackBar]. The "you're offline" message is persistent, under a fixed
/// [_tag] distinct from [OfflineSyncBanner]'s so the two can stack
/// independently; once connectivity returns, that persistent banner is
/// swapped for a brief "connection restored" confirmation (a plain,
/// auto-dismissing toast — not tagged/persistent, since it doesn't need
/// updating in place) so the user sees the state actually changed, rather
/// than the offline banner just silently vanishing. The separate "you have
/// data to sync" banner still takes over on its own if there's anything
/// pending.
final class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

final class _ConnectivityBannerState extends State<ConnectivityBanner> {
  static const _tag = 'connectivity';

  // Only true once this widget has actually observed ConnectivityOffline —
  // guards the "connection restored" toast so it fires on a genuine
  // offline→online transition, never on first mount while already online.
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _present(context.read<ConnectivityCubit>().state);
    });
  }

  @override
  void dispose() {
    AppSnackBar.hide(_tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityCubit, ConnectivityState>(
      listener: (_, state) => _present(state),
      child: const SizedBox.shrink(),
    );
  }

  void _present(ConnectivityState state) {
    if (state is ConnectivityOffline) {
      _wasOffline = true;
      AppSnackBar.show(
        context,
        tag: _tag,
        duration: null,
        variant: AppSnackBarVariant.warning,
        message: 'sync.banner.offline'.tr(),
      );
      return;
    }

    AppSnackBar.hide(_tag);
    if (_wasOffline) {
      _wasOffline = false;
      AppSnackBar.show(context, variant: AppSnackBarVariant.success, message: 'sync.banner.back_online'.tr());
    }
  }
}
