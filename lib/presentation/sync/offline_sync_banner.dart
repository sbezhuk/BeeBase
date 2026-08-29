import 'package:beebase/presentation/sync/cubit/sync_banner_cubit/sync_banner_cubit.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_card.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide "offline data available" banner — rendered inside the main tab
/// shell (not the pre-auth screens). Purely a [SyncBannerCubit] view: hidden
/// when there's nothing to sync or the device is offline, otherwise the
/// existing [AppSnackBarCard] look with a "Sync now" action, swapped for a
/// progress spinner while a sync is running.
final class OfflineSyncBanner extends StatelessWidget {
  const OfflineSyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBannerCubit, SyncBannerState>(
      builder: (context, state) {
        if (state is SyncBannerHidden) {
          return const SizedBox.shrink();
        }

        final cubit = context.read<SyncBannerCubit>();
        final isSyncing = state is SyncBannerSyncing;
        return SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.sm, context.spacing.md, 0),
            child: AppSnackBarCard(
              message: isSyncing ? 'sync.banner.syncing'.tr() : 'sync.banner.message'.tr(),
              actionLabel: isSyncing ? null : 'sync.banner.action'.tr(),
              onAction: isSyncing ? null : cubit.sync,
              onDismiss: isSyncing ? null : cubit.dismiss,
              trailing: isSyncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
            ),
          ),
        );
      },
    );
  }
}
