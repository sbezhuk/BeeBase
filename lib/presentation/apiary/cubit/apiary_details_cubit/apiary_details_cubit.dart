import 'dart:async';

import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/apiary_details_state.dart';
part 'state/apiary_details_loaded.dart';
part 'mixin/apiary_details_emitter.dart';

/// Keeps one Apiary's details current after a background sync. Seeded
/// synchronously with the [Apiary] passed in from the list/route (opening
/// this page never needs a network round trip), then re-read from the local
/// cache whenever [ApiaryListRefreshNotifier] fires — the same signal
/// [ApiaryListCubit] already reacts to for the list screen. This is what
/// picks up, e.g., an address [ApiaryOperationHandler] re-resolved from an
/// offline placeholder once a queued create/update operation synced.
///
/// The hive count is fetched separately (see [loadHiveCount]) and kept fresh
/// via [HiveListRefreshNotifier] — the same signal a hive create/edit/delete
/// fires that [HiveListCubit] already reacts to — so adding a hive updates
/// this screen's count without the user needing to back out and re-enter.
class ApiaryDetailsCubit extends Cubit<ApiaryDetailsState> with ApiaryDetailsEmitter {
  ApiaryDetailsCubit({
    required Apiary apiary,
    required this.reader,
    required this.hiveReader,
    required this.refreshNotifier,
    required this.hiveRefreshNotifier,
  }) : super(ApiaryDetailsLoaded(apiary)) {
    _subscription = refreshNotifier.onChanged.listen((_) => refreshFromCache());
    _hiveSubscription = hiveRefreshNotifier.onChanged.listen((_) => loadHiveCount());
  }

  final IApiaryReader reader;
  final IHiveReader hiveReader;
  final ApiaryListRefreshNotifier refreshNotifier;
  final HiveListRefreshNotifier hiveRefreshNotifier;
  StreamSubscription<void>? _subscription;
  StreamSubscription<void>? _hiveSubscription;

  /// Applied when the edit form pops back with a freshly saved [Apiary] —
  /// no need to wait for the next refresh signal to reflect that edit.
  void setApiary(Apiary apiary) => emitLoaded(apiary);

  Future<void> refreshFromCache() async {
    final fresh = await reader.getCachedApiary(state.apiary.id);
    if (fresh != null) emitLoaded(fresh);
  }

  /// Fetches this apiary's real hive count — called once when the details
  /// page opens (see `ApiaryDetailsPage.wrappedRoute`) and again whenever
  /// [hiveRefreshNotifier] fires. A fetch failure is ignored rather than
  /// surfaced: the count is a secondary stat and shouldn't block or error
  /// out the rest of an already-loaded details screen.
  Future<void> loadHiveCount() async {
    final result = await hiveReader.getHiveCounts();
    result.fold((_) {}, (counts) => emitLoaded(state.apiary, hiveCount: counts[state.apiary.id] ?? 0));
  }

  @override
  Future<void> close() {
    unawaited(_subscription?.cancel());
    unawaited(_hiveSubscription?.cancel());
    return super.close();
  }
}
