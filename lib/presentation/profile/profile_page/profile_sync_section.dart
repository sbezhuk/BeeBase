part of '../profile_page.dart';

/// Manual "sync offline data" action for Profile — reads the same global
/// [SyncBannerCubit] the banner does (see `OfflineSyncBanner`), so both stay
/// in lockstep, but stays visible here regardless of whether the banner was
/// dismissed, giving the user a place to check status and trigger a sync on
/// demand.
///
/// Rendered as a single tappable settings-style row (icon, status text,
/// trailing indicator) matching every other row on this screen, rather than
/// a standalone full-width button.
///
/// Deliberately keyed off [SyncEngine.hasPendingOperations] rather than
/// [SyncBannerCubit]'s own state: the cubit's Hidden/Available only flips to
/// Available when the device is *also* online (that's the right rule for
/// the banner, which exists to offer an actionable "sync now"), but here the
/// row should read "there's data to sync" whenever a pending/failed
/// operation exists at all — including while offline — so it doesn't
/// falsely claim "everything is synced" just because there's no connection
/// right now.
final class _ProfileSyncSection extends StatefulWidget {
  const _ProfileSyncSection();

  @override
  State<_ProfileSyncSection> createState() => _ProfileSyncSectionState();
}

final class _ProfileSyncSectionState extends State<_ProfileSyncSection> {
  /// Set once a manual [SyncBannerCubit.sync] completes without clearing
  /// every pending operation — [SyncEngine] itself has no dedicated "last
  /// attempt failed" signal (see its own doc), so this is derived from the
  /// one thing it does expose: [SyncEngine.hasPendingOperations] staying
  /// true right after a sync attempt that should have cleared it. Reset the
  /// moment another sync starts, or the moment everything does clear.
  bool _lastAttemptFailed = false;

  Future<void> _sync(SyncBannerCubit cubit) async {
    setState(() => _lastAttemptFailed = false);
    await cubit.sync();
    if (!mounted) return;
    setState(() => _lastAttemptFailed = cubit.engine.hasPendingOperations.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connectivityState) {
        final isOffline = connectivityState is ConnectivityOffline;
        return BlocBuilder<SyncBannerCubit, SyncBannerState>(
          builder: (context, state) {
            final cubit = context.read<SyncBannerCubit>();
            final isSyncing = state is SyncBannerSyncing;
            return ValueListenableBuilder<bool>(
              valueListenable: cubit.engine.hasPendingOperations,
              builder: (context, hasPending, _) {
                final showFailed = _lastAttemptFailed && hasPending && !isSyncing;
                final Color statusColor;
                final String statusText;
                final IconData statusIcon;
                if (isSyncing) {
                  statusColor = colors.text.secondary;
                  statusText = 'sync.banner.syncing'.tr();
                  statusIcon = Icons.cloud_sync_outlined;
                } else if (hasPending && isOffline) {
                  statusColor = colors.text.secondary;
                  statusText = 'sync.banner.offline'.tr();
                  statusIcon = Icons.cloud_off_outlined;
                } else if (showFailed) {
                  statusColor = colors.status.error;
                  statusText = 'profile.page.sync.failed'.tr();
                  statusIcon = Icons.error_outline;
                } else if (hasPending) {
                  statusColor = colors.status.warning;
                  statusText = 'profile.page.sync.pending'.tr();
                  statusIcon = Icons.cloud_upload_outlined;
                } else {
                  statusColor = colors.brand.primary;
                  statusText = 'profile.page.sync.up_to_date'.tr();
                  statusIcon = Icons.cloud_done_outlined;
                }
                final canTap = hasPending && !isSyncing && !isOffline;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.page.sync.title'.tr().toUpperCase(),
                      style: context.textStyles.label.copyWith(color: colors.honey.muted),
                    ),
                    SizedBox(height: context.spacing.sm),
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: canTap ? () => _sync(cubit) : null,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: context.spacing.sm, horizontal: context.spacing.xs),
                          child: Row(
                            children: [
                              Icon(statusIcon, size: 20, color: statusColor),
                              SizedBox(width: context.spacing.sm),
                              Expanded(child: Text(statusText, style: context.textStyles.body)),
                              if (isSyncing)
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(colors.brand.primary),
                                  ),
                                )
                              else if (canTap)
                                Icon(Icons.sync, size: 20, color: colors.brand.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
