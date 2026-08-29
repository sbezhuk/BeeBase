import 'package:beebase/presentation/sync/cubit/sync_banner_cubit/sync_banner_cubit.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_variant.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide "offline data available" notification — mounted inside the main
/// tab shell (not the pre-auth screens). Renders nothing itself: it's purely
/// a [SyncBannerCubit] listener that drives the shared [AppSnackBar] under a
/// fixed [_tag], so the notification appears as a bottom snack bar (stacked
/// with, and using the same look as, every other [AppSnackBar.show] caller)
/// rather than a bespoke banner. Hidden when there's nothing to sync or the
/// device is offline; shows a "Sync now" action, swapped for a loading state
/// while [SyncBannerCubit.sync] is running.
final class OfflineSyncBanner extends StatefulWidget {
  const OfflineSyncBanner({super.key});

  @override
  State<OfflineSyncBanner> createState() => _OfflineSyncBannerState();
}

final class _OfflineSyncBannerState extends State<OfflineSyncBanner> {
  static const _tag = 'offline-sync';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _present(context.read<SyncBannerCubit>().state);
    });
  }

  @override
  void dispose() {
    AppSnackBar.hide(_tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SyncBannerCubit, SyncBannerState>(
      listener: (_, state) => _present(state),
      child: const SizedBox.shrink(),
    );
  }

  void _present(SyncBannerState state) {
    if (state is SyncBannerHidden) {
      AppSnackBar.hide(_tag);
      return;
    }

    final cubit = context.read<SyncBannerCubit>();
    final isSyncing = state is SyncBannerSyncing;
    AppSnackBar.show(
      context,
      tag: _tag,
      duration: null,
      variant: AppSnackBarVariant.warning,
      message: isSyncing ? 'sync.banner.syncing'.tr() : 'sync.banner.message'.tr(),
      actionLabel: isSyncing ? null : 'sync.banner.action'.tr(),
      onAction: isSyncing ? null : cubit.sync,
      onDismiss: isSyncing ? null : cubit.dismiss,
      isLoading: isSyncing,
    );
  }
}
