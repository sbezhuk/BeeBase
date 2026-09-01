import 'dart:async';

import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
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
class ApiaryDetailsCubit extends Cubit<ApiaryDetailsState> with ApiaryDetailsEmitter {
  ApiaryDetailsCubit({required Apiary apiary, required this.reader, required this.refreshNotifier})
    : super(ApiaryDetailsLoaded(apiary)) {
    _subscription = refreshNotifier.onChanged.listen((_) => refreshFromCache());
  }

  final IApiaryReader reader;
  final ApiaryListRefreshNotifier refreshNotifier;
  StreamSubscription<void>? _subscription;

  /// Applied when the edit form pops back with a freshly saved [Apiary] —
  /// no need to wait for the next refresh signal to reflect that edit.
  void setApiary(Apiary apiary) => emitLoaded(apiary);

  Future<void> refreshFromCache() async {
    final fresh = await reader.getCachedApiary(state.apiary.id);
    if (fresh != null) emitLoaded(fresh);
  }

  @override
  Future<void> close() {
    unawaited(_subscription?.cancel());
    return super.close();
  }
}
