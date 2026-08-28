part of '../apiary_list_page.dart';

/// Small "still syncing"/"sync failed" indicator shown on a list tile whose
/// apiary hasn't reached [ApiarySyncStatus.synced] yet — see
/// `ApiaryRepositoryImpl` for how that status is derived from the offline
/// operation queue.
final class _ApiarySyncBadge extends StatelessWidget {
  const _ApiarySyncBadge({required this.status});

  final ApiarySyncStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isFailed = status == ApiarySyncStatus.failed;
    final color = isFailed ? colors.status.error : colors.text.secondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isFailed ? Icons.sync_problem : Icons.sync, size: 14, color: color),
        SizedBox(width: context.spacing.xs),
        Text(
          isFailed ? 'apiary.list.syncFailed'.tr() : 'apiary.list.syncPending'.tr(),
          style: context.textStyles.label.copyWith(color: color),
        ),
      ],
    );
  }
}
