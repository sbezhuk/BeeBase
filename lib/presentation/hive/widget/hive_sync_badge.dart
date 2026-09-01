import 'package:beebase/domain/enum/hive_sync_status.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Small "needs synchronization"/"sync failed" indicator for a hive whose
/// [HiveSyncStatus] hasn't reached [HiveSyncStatus.synced] yet — mirrors
/// [ApiarySyncBadge]. Shared by the list tile and the details page so both
/// surfaces flag not-yet-synced data the same way.
final class HiveSyncBadge extends StatelessWidget {
  const HiveSyncBadge({required this.status, super.key});

  final HiveSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isFailed = status == HiveSyncStatus.failed;
    final color = isFailed ? colors.status.error : colors.text.secondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isFailed ? Icons.sync_problem : Icons.sync,
          size: 14,
          color: color,
        ),
        SizedBox(width: context.spacing.xs),
        Text(
          isFailed ? 'hive.list.sync_failed'.tr() : 'hive.list.sync_pending'.tr(),
          style: context.textStyles.label.copyWith(color: color),
        ),
      ],
    );
  }
}
