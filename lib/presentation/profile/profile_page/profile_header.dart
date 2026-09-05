part of '../profile_page.dart';

/// Identity card at the top of the Profile page — avatar, name, email and a
/// "member since" badge grouped into one elevated [colors.surface.card]
/// surface (mirroring [ApiarySectionCard]/[HiveSectionCard]'s card shape) so
/// the user's identity reads as the page's clear focal point rather than a
/// plain centered text stack. Member-since used to live in a separate
/// "account information" section that only ever restated this same email
/// alongside it — folding it in here removes that duplication.
final class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  String get _displayName {
    final first = user.firstName?.trim() ?? '';
    final last = user.lastName?.trim() ?? '';
    final full = [first, last].where((part) => part.isNotEmpty).join(' ');
    return full.isEmpty ? 'profile.page.name_placeholder'.tr() : full;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: spacing.lg,
        horizontal: spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.brand.primary.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: ProfileAvatar(
              resolver: di<AvatarImageResolver>(),
              avatarId: user.avatarId,
              size: 92,
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            _displayName,
            style: context.textStyles.title,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.xs),
          Text(
            user.email,
            style: context.textStyles.body.copyWith(
              color: colors.text.secondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.sm),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.honey.cream,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: colors.honey.muted,
                ),
                SizedBox(width: spacing.xs),
                Text(
                  '${'profile.page.member_since'.tr()} ${user.createdAt.toProfileDisplayDate()}',
                  style: context.textStyles.label.copyWith(
                    color: colors.honey.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
