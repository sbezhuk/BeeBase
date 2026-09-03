part of '../home_page.dart';

/// Reached only via a per-section retry — the bulk first load uses the
/// full-screen [LoadingOverlay] instead of this.
final class _DashboardSectionLoading extends StatelessWidget {
  const _DashboardSectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator.adaptive(),
      ),
    );
  }
}
