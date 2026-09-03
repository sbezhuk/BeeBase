part of '../home_page.dart';

/// Switches one Dashboard section's [DashboardSection] on loading/error/data
/// — used by all four sections so the loading/error chrome is written once.
final class _DashboardSectionSwitcher<T> extends StatelessWidget {
  const _DashboardSectionSwitcher({
    required this.section,
    required this.onRetry,
    required this.builder,
  });

  final DashboardSection<T> section;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      SectionLoading<T>() => const _DashboardSectionLoading(),
      SectionError<T>(:final failure) => _DashboardSectionError(
        failure: failure,
        onRetry: onRetry,
      ),
      SectionData<T>(:final value) => builder(context, value),
    };
  }
}
