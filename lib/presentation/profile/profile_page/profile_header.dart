part of '../profile_page.dart';

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
    return Center(
      child: Column(
        children: [
          ProfileAvatar(
            resolver: di<AvatarImageResolver>(),
            avatarId: user.avatarId,
            size: 96,
          ),
          SizedBox(height: context.spacing.md),
          Text(_displayName, style: context.textStyles.title),
          SizedBox(height: context.spacing.xs),
          Text(
            user.email,
            style: context.textStyles.body.copyWith(
              color: context.colors.text.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
