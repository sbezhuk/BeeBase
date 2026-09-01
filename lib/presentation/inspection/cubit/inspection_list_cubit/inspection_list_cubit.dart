import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/repositories/inspection_reader.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:beebase/utils/pagination/pagination_defaults.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/inspection_list_state.dart';
part 'state/inspection_list_loading.dart';
part 'state/inspection_list_loaded.dart';
part 'state/inspection_list_error.dart';
part 'mixin/inspection_list_emitter.dart';

final class InspectionListCubit extends Cubit<InspectionListState> with InspectionListEmitter {
  InspectionListCubit({required this.reader, required this.hiveId, required this.refreshNotifier})
    : super(const InspectionListLoading()) {
    _refreshSubscription = refreshNotifier.onChanged.listen((_) => refresh());
  }

  final IInspectionReader reader;
  final String hiveId;
  final InspectionListRefreshNotifier refreshNotifier;
  late final StreamSubscription<void> _refreshSubscription;

  /// Initial/forced load — replaces the body with a full-screen spinner.
  Future<void> loadInspections() => emitLoadInspections(reader, hiveId);

  /// Pull-to-refresh — keeps the current list visible while refetching.
  Future<void> refresh() => emitRefreshInspections(reader, hiveId);

  /// Fetches the next page and appends it. No-op if a page is already
  /// loading, there is no next page, or the list hasn't loaded yet.
  Future<void> loadNextPage() => emitLoadNextPage(reader, hiveId);

  /// Retries the page that just failed to load — the failed attempt never
  /// advances [InspectionListLoaded.page], so this re-requests the same page.
  Future<void> retryLoadNextPage() => emitLoadNextPage(reader, hiveId);

  @override
  Future<void> close() {
    _refreshSubscription.cancel();
    return super.close();
  }
}
