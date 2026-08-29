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

  /// Pushes [entry] onto the stack. If [entry] carries a [AppSnackBarEntry.tag]
  /// that already matches a currently-showing entry, that entry is replaced
  /// in place (same position, same widget identity) instead of stacking a
  /// duplicate — see [AppSnackBarEntry] for why this matters for persistent,
  /// state-driven banners.
  static void enqueue(BuildContext context, AppSnackBarEntry entry) {
    _ensureMounted(context);
    final tag = entry.tag;
    final existingIndex = tag == null ? -1 : entries.value.indexWhere((e) => e.tag == tag);
    if (existingIndex == -1) {
      entries.value = [...entries.value, entry];
      return;
    }
    final updated = [...entries.value];
    updated[existingIndex] = entry.copyWithId(updated[existingIndex].id);
    entries.value = updated;
  }

  static void remove(Key id) {
    entries.value = entries.value.where((entry) => entry.id != id).toList();
  }

  /// Removes the currently-showing entry tagged [tag], if any — the
  /// programmatic counterpart to a user tapping an entry's dismiss button.
  static void removeByTag(String tag) {
    entries.value = entries.value.where((entry) => entry.tag != tag).toList();
  }

  static void _ensureMounted(BuildContext context) {
    // Recreate rather than reuse once unmounted (e.g. the root Overlay this
    // was inserted into has since been torn down) — otherwise this static
    // singleton would keep pointing at a dead entry forever.
    if (_overlayEntry?.mounted ?? false) return;
    _overlayEntry = OverlayEntry(builder: (_) => const AppSnackBarStack());
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }
}
