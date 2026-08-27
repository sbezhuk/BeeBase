part of '../apiary_list_page.dart';

final class _ApiaryListErrorView extends StatelessWidget {
  const _ApiaryListErrorView({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.error),
            SizedBox(height: context.spacing.md),
            Text(failure.message.resolve(), style: context.textStyles.body, textAlign: TextAlign.center),
            SizedBox(height: context.spacing.lg),
            _RetryButton(onPressed: () => context.read<ApiaryListCubit>().loadApiaries()),
          ],
        ),
      ),
    );
  }
}

final class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = 'apiary.list.retry'.tr();
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => GlassButton.custom(onTap: onPressed, width: 140, height: 44, child: Text(label)),
      _ => FilledButton.tonal(onPressed: onPressed, child: Text(label)),
    };
  }
}
