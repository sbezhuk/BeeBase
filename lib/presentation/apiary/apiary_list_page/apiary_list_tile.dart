part of '../apiary_list_page.dart';

/// Dispatches to the platform-appropriate tile presentation — a Liquid Glass
/// row on iOS, a Material 3 card on Android — while both read the same
/// [Apiary] and share the same navigation behavior.
final class _ApiaryListTile extends StatelessWidget {
  const _ApiaryListTile({required this.apiary});

  final Apiary apiary;

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => _IosApiaryListTile(apiary: apiary, onTap: () => _openDetails(context)),
      _ => _AndroidApiaryListTile(apiary: apiary, onTap: () => _openDetails(context)),
    };
  }

  void _openDetails(BuildContext context) {
    // ApiaryDetailsRoute is a root-level route (a sibling of MainRoute, not
    // nested under this tab), so it must be pushed via the root router —
    // context.router here is scoped to this tab's own stack, which doesn't
    // know this route exists. Any edit/delete made there reaches the list
    // via ApiaryListRefreshNotifier, so there's nothing to await here.
    context.router.root.push(ApiaryDetailsRoute(apiary: apiary));
  }
}
