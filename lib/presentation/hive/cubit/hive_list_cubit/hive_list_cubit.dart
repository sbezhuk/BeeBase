import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/utils/pagination/pagination_defaults.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/hive_list_state.dart';
part 'state/hive_list_loading.dart';
part 'state/hive_list_loaded.dart';
part 'state/hive_list_error.dart';
part 'mixin/hive_list_emitter.dart';

final class HiveListCubit extends Cubit<HiveListState> with HiveListEmitter {
  HiveListCubit({
    required this.reader,
    required this.apiaryId,
    required this.refreshNotifier,
  }) : super(const HiveListLoading()) {
    _refreshSubscription = refreshNotifier.onChanged.listen((_) => refresh());
  }

  final IHiveReader reader;
  final String apiaryId;
  final HiveListRefreshNotifier refreshNotifier;
  late final StreamSubscription<void> _refreshSubscription;

  /// Initial/forced load — replaces the body with a full-screen spinner.
  Future<void> loadHives() => emitLoadHives(reader, apiaryId);

  /// Pull-to-refresh — keeps the current list visible while refetching.
  Future<void> refresh() => emitRefreshHives(reader, apiaryId);

  /// Fetches the next page and appends it. No-op if a page is already
  /// loading, there is no next page, or the list hasn't loaded yet.
  Future<void> loadNextPage() => emitLoadNextPage(reader, apiaryId);

  /// Retries the page that just failed to load — the failed attempt never
  /// advances [HiveListLoaded.page], so this re-requests the same page.
  Future<void> retryLoadNextPage() => emitLoadNextPage(reader, apiaryId);

  @override
  Future<void> close() {
    _refreshSubscription.cancel();
    return super.close();
  }
}
