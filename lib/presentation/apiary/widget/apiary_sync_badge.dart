import 'package:beebase/domain/enum/local/apiary_sync_status.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Small "needs synchronization"/"sync failed" indicator for an apiary
/// whose [ApiarySyncStatus] hasn't reached [ApiarySyncStatus.synced] yet —
/// see `ApiaryRepositoryImpl` for how that status is derived from the
/// offline operation queue. Shared by the list tile and the details page so
/// both surfaces flag not-yet-synced data the same way.
final class ApiarySyncBadge extends StatelessWidget {
  const ApiarySyncBadge({required this.status, super.key});

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
          isFailed ? 'apiary.list.sync_failed'.tr() : 'apiary.list.sync_pending'.tr(),
          style: context.textStyles.label.copyWith(color: color),
        ),
      ],
    );
  }
}
