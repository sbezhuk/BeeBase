part of '../home_page.dart';

/// Wraps a Dashboard tile that must fetch the full entity before navigating
/// (the statistics endpoints only return id+name, not the whole `Apiary`/
/// `Hive`/`Inspection` the existing `*DetailsRoute`s need). Disables the tap
/// and shows a trailing spinner while [onTap] is in flight; a failure shows
/// a snackbar with the resolved failure message rather than navigating.
final class _DashboardTappableTile extends StatefulWidget {
  const _DashboardTappableTile({required this.child, required this.onTap});

  final Widget child;
  final Future<void> Function() onTap;

  @override
  State<_DashboardTappableTile> createState() => _DashboardTappableTileState();
}

final class _DashboardTappableTileState extends State<_DashboardTappableTile> {
  bool _isPending = false;

  Future<void> _handleTap() async {
    if (_isPending) return;
    setState(() => _isPending = true);
    await widget.onTap();
    if (mounted) setState(() => _isPending = false);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isPending ? null : _handleTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(child: widget.child),
          if (_isPending)
            Padding(
              padding: EdgeInsets.only(left: context.spacing.sm),
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            )
          else
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.colors.text.secondary,
            ),
        ],
      ),
    );
  }
}

/// Fetches [request] and either calls [onSuccess] with the result or shows
/// a snackbar with the resolved failure message. Shared by every Dashboard
/// tap target so each one only has to say what to fetch and where to go.
Future<void> _fetchThenNavigate<T>({
  required BuildContext context,
  required Future<Either<Failure, T>> Function() request,
  required void Function(T value) onSuccess,
}) async {
  final result = await request();
  if (!context.mounted) return;
  result.fold(
    (failure) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message.resolve()))),
    onSuccess,
  );
}
