part of '../apiary_list_page.dart';

final class _ApiaryListLoadedView extends StatelessWidget {
  const _ApiaryListLoadedView({required this.apiaries});

  final List<Apiary> apiaries;

  @override
  Widget build(BuildContext context) {
    if (apiaries.isEmpty) {
      return const SliverFillRemaining(hasScrollBody: false, child: _ApiaryListEmptyView());
    }
    return SliverPadding(
      padding: EdgeInsets.only(top: context.spacing.md, bottom: context.spacing.lg),
      sliver: SliverList.separated(
        itemCount: apiaries.length,
        separatorBuilder: (context, index) => SizedBox(height: context.spacing.md),
        itemBuilder: (context, index) => _ApiaryListTile(apiary: apiaries[index]),
      ),
    );
  }
}
