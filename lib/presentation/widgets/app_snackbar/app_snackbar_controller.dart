import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_entry.dart';
import 'package:beebase/presentation/widgets/app_snackbar/app_snackbar_stack.dart';
import 'package:flutter/widgets.dart';

/// App-wide toast stack: holds the queued [AppSnackBarEntry] list behind a
/// [ValueNotifier] and lazily mounts a single root-level [OverlayEntry] the
/// first time [enqueue] is called, so [AppSnackBar.show] can be invoked from
/// anywhere without callers worrying about setup.
final class AppSnackBarController {
  AppSnackBarController._();

  static final ValueNotifier<List<AppSnackBarEntry>> entries = ValueNotifier([]);

  static OverlayEntry? _overlayEntry;

  static void enqueue(BuildContext context, AppSnackBarEntry entry) {
    _ensureMounted(context);
    entries.value = [...entries.value, entry];
  }

  static void remove(Key id) {
    entries.value = entries.value.where((entry) => entry.id != id).toList();
  }

  static void _ensureMounted(BuildContext context) {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(builder: (_) => const AppSnackBarStack());
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }
}
