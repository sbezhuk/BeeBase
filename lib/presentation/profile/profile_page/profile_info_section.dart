part of '../profile_page.dart';

final class _ProfileInfoSection extends StatelessWidget {
  const _ProfileInfoSection({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'profile.page.account_info'.tr().toUpperCase(),
          style: context.textStyles.label.copyWith(
            color: context.colors.honey.muted,
          ),
        ),
        SizedBox(height: context.spacing.sm),
        _ProfileInfoRow(label: 'profile.page.email'.tr(), value: user.email),
        SizedBox(height: context.spacing.sm),
        _ProfileInfoRow(
          label: 'profile.page.member_since'.tr(),
          value: user.createdAt.toProfileDisplayDate(),
        ),
      ],
    );
  }
}
