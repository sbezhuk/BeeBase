part of '../inspection_list_page.dart';

final class _InspectionListErrorView extends StatelessWidget {
  const _InspectionListErrorView({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.status.error),
            SizedBox(height: context.spacing.md),
            Text(
              failure.message.resolve(),
              style: context.textStyles.body,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.spacing.lg),
            RetryButton(onPressed: () => context.read<InspectionListCubit>().loadInspections()),
          ],
        ),
      ),
    );
  }
}
