import 'package:beebase/presentation/connectivity/cubit/connectivity_cubit/connectivity_cubit.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide "you're offline" notification — mounted inside the main tab
/// shell alongside [OfflineSyncBanner] (not the pre-auth screens). Renders
/// nothing itself: it's purely a [ConnectivityCubit] listener that drives
/// the shared [AppSnackBar] under a fixed [_tag] distinct from
/// [OfflineSyncBanner]'s, so the two can stack independently rather than
/// clobbering each other. Shown while [ConnectivityOffline]; hidden as soon
/// as connectivity returns — the separate "you have data to sync" banner
/// then takes over if there's anything pending.
final class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

final class _ConnectivityBannerState extends State<ConnectivityBanner> {
  static const _tag = 'connectivity';

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
    if (state is ConnectivityOnline) {
      AppSnackBar.hide(_tag);
      return;
    }

    AppSnackBar.show(context, tag: _tag, duration: null, variant: AppSnackBarVariant.warning, message: 'sync.banner.offline'.tr());
  }
}
