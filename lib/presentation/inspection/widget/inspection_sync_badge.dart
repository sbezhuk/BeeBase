import 'package:beebase/domain/enum/inspection_sync_status.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Small "needs synchronization"/"sync failed" indicator for an inspection
/// whose [InspectionSyncStatus] hasn't reached [InspectionSyncStatus.synced]
/// yet — mirrors [HiveSyncBadge]. Shared by the list tile and the details
/// page so both surfaces flag not-yet-synced data the same way.
final class InspectionSyncBadge extends StatelessWidget {
  const InspectionSyncBadge({required this.status, super.key});

  final InspectionSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isFailed = status == InspectionSyncStatus.failed;
    final color = isFailed ? colors.status.error : colors.text.secondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isFailed ? Icons.sync_problem : Icons.sync, size: 14, color: color),
        SizedBox(width: context.spacing.xs),
        Text(
          isFailed ? 'inspection.list.syncFailed'.tr() : 'inspection.list.syncPending'.tr(),
          style: context.textStyles.label.copyWith(color: color),
        ),
      ],
    );
  }
}
