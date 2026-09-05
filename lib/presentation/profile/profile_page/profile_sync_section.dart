part of '../profile_page.dart';

final class ProfileSyncSection extends StatefulWidget {
  const ProfileSyncSection({super.key});

  @override
  State<ProfileSyncSection> createState() => _ProfileSyncSectionState();
}

final class _ProfileSyncSectionState extends State<ProfileSyncSection> {
  int? _pendingCount;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final apiaryLocalDataSource = di<IApiaryLocalDataSource>();
      final hiveLocalDataSource = di<IHiveLocalDataSource>();
      final inspectionLocalDataSource = di<IInspectionLocalDataSource>();
      final pendingApiaries = await apiaryLocalDataSource.getPendingSyncApiaries();
      final pendingHives = await hiveLocalDataSource.getPendingSyncHives();
      final pendingInspections = await inspectionLocalDataSource.getPendingSyncInspections();
      if (mounted) {
        setState(() {
          _pendingCount = pendingApiaries.length + pendingHives.length + pendingInspections.length;
        });
      }
    } catch (_) {
      // Gracefully ignore if database or table not available yet
    }
  }

  Future<void> _sync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final synchronizer = di<IDataSynchronizer>();
      final result = await synchronizer.syncAll();

      if (!mounted) return;

      await _loadPendingCount();

      if (result.errors.isNotEmpty && result.syncedCount == 0 && result.failedCount == 0) {
        AppSnackBar.show(context, message: 'profile.page.sync_no_internet'.tr(), variant: AppSnackBarVariant.warning);
      } else if (result.syncedCount > 0) {
        AppSnackBar.show(
          context,
          message: 'profile.page.sync_success'.tr(namedArgs: {'count': result.syncedCount.toString()}),
          variant: AppSnackBarVariant.success,
        );
      } else if (result.failedCount > 0) {
        AppSnackBar.show(context, message: 'profile.page.sync_failed'.tr(), variant: AppSnackBarVariant.error);
      } else {
        AppSnackBar.show(context, message: 'profile.page.sync_all_synced'.tr(), variant: AppSnackBarVariant.neutral);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, message: 'profile.page.sync_failed'.tr(), variant: AppSnackBarVariant.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('profile.page.sync_section'.tr().toUpperCase(), style: context.textStyles.label.copyWith(color: colors.honey.muted)),
        SizedBox(height: context.spacing.sm),
        Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.sm, horizontal: context.spacing.xs),
            child: Row(
              children: [
                Icon(Icons.sync, size: 20, color: colors.brand.primary),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('profile.page.sync_data'.tr(), style: context.textStyles.body),
                      if (_pendingCount != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _pendingCount == 0
                              ? 'profile.page.sync_all_synced'.tr()
                              : 'profile.page.sync_pending_count'.tr(namedArgs: {'count': '$_pendingCount'}),
                          style: context.textStyles.label.copyWith(
                            color: _pendingCount == 0 ? colors.text.secondary : colors.status.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: context.spacing.sm),
                if (_isSyncing)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                else
                  GestureDetector(
                    onTap: _isSyncing ? null : _sync,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm, vertical: context.spacing.xs),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: colors.brand.primary.withValues(alpha: 0.12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 16, color: colors.brand.primary),
                          const SizedBox(width: 4),
                          Text(
                            'profile.page.sync_now'.tr(),
                            style: context.textStyles.label.copyWith(color: colors.brand.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
