part of '../profile_page.dart';

final class _ProfileAppVersion extends StatelessWidget {
  const _ProfileAppVersion();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) {
          return const SizedBox.shrink();
        }
        return Center(
          child: Text(
            'profile.page.app_version'.tr(
              namedArgs: {'version': info.version, 'build': info.buildNumber},
            ),
            style: context.textStyles.label.copyWith(
              color: context.colors.text.secondary,
            ),
          ),
        );
      },
    );
  }
}
