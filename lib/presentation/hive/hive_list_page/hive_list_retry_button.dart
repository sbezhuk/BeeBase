part of '../hive_list_page.dart';

final class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = 'hive.list.retry'.tr();
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => GlassButton.custom(
        onTap: onPressed,
        width: 140,
        height: 44,
        child: Text(label),
      ),
      _ => FilledButton.tonal(onPressed: onPressed, child: Text(label)),
    };
  }
}
