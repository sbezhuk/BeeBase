part of '../apiary_list_page.dart';

final class _IosApiaryListTile extends StatelessWidget {
  const _IosApiaryListTile({required this.apiary, required this.onTap});

  final Apiary apiary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLocation = apiary.location != null && apiary.location!.isNotEmpty;
    return GlassListTile.standalone(
      leading: const ApiaryHexagonBadge(),
      title: Text(apiary.name, style: context.textStyles.body),
      subtitle: hasLocation ? Text(apiary.location!, style: context.textStyles.label) : null,
      trailing: GlassListTile.chevron,
      onTap: onTap,
      settings: apiaryGlassSettings(context.colors),
    );
  }
}
