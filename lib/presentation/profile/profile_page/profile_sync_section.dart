part of '../profile_page.dart';

/// Manual "sync offline data" action for Profile — reads the same global
/// [SyncBannerCubit] the banner does (see `OfflineSyncBanner`), so both stay
/// in lockstep, but stays visible here regardless of whether the banner was
/// dismissed, giving the user a place to check status and trigger a sync on
/// demand.
///
/// Deliberately keyed off [SyncEngine.hasPendingOperations] rather than
/// [SyncBannerCubit]'s own state: the cubit's Hidden/Available only flips to
/// Available when the device is *also* online (that's the right rule for
/// the banner, which exists to offer an actionable "sync now"), but here the
/// button should read "there's data to sync" whenever a pending/failed
/// operation exists at all — including while offline — so it doesn't
/// falsely claim "everything is synced" just because there's no connection
/// right now.
final class _ProfileSyncSection extends StatelessWidget {
  const _ProfileSyncSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBannerCubit, SyncBannerState>(
      builder: (context, state) {
        final cubit = context.read<SyncBannerCubit>();
        final isSyncing = state is SyncBannerSyncing;
        return ValueListenableBuilder<bool>(
          valueListenable: cubit.engine.hasPendingOperations,
          builder: (context, hasPending, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'profile.page.sync.title'.tr(),
                  style: context.textStyles.label.copyWith(color: context.colors.honey.muted),
                ),
                SizedBox(height: context.spacing.xs),
                Text(
                  hasPending ? 'profile.page.sync.pending'.tr() : 'profile.page.sync.upToDate'.tr(),
                  style: context.textStyles.body,
                ),
                SizedBox(height: context.spacing.sm),
                PrimaryButton(
                  label: isSyncing ? 'sync.banner.syncing'.tr() : 'sync.banner.action'.tr(),
                  isLoading: isSyncing,
                  onPressed: hasPending ? cubit.sync : null,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
