import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/domain/repositories/hive_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/utils/pagination/pagination_defaults.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/apiary_list_state.dart';
part 'state/apiary_list_loading.dart';
part 'state/apiary_list_loaded.dart';
part 'state/apiary_list_error.dart';
part 'mixin/apiary_list_emitter.dart';

final class ApiaryListCubit extends Cubit<ApiaryListState> with ApiaryListEmitter {
  ApiaryListCubit({
    required this.reader,
    required this.hiveReader,
    required this.refreshNotifier,
    required this.hiveRefreshNotifier,
  }) : super(const ApiaryListLoading()) {
    _refreshSubscription = refreshNotifier.onChanged.listen((_) => refresh());
    _hiveRefreshSubscription = hiveRefreshNotifier.onChanged.listen((_) => refresh());
  }

  final IApiaryReader reader;
  final IHiveReader hiveReader;
  final ApiaryListRefreshNotifier refreshNotifier;
  final HiveListRefreshNotifier hiveRefreshNotifier;
  late final StreamSubscription<void> _refreshSubscription;
  late final StreamSubscription<void> _hiveRefreshSubscription;

  /// Initial/forced load — replaces the body with a full-screen spinner.
  Future<void> loadApiaries() => emitLoadApiaries(reader, hiveReader);

  /// Pull-to-refresh — keeps the current list visible while refetching. Also
  /// re-fetches hive counts, since a hive create/edit/delete/sync elsewhere
  /// signals here through [hiveRefreshNotifier].
  Future<void> refresh() => emitRefreshApiaries(reader, hiveReader);

  /// Fetches the next page and appends it. No-op if a page is already
  /// loading, there is no next page, or the list hasn't loaded yet.
  Future<void> loadNextPage() => emitLoadNextPage(reader);

  /// Retries the page that just failed to load — the failed attempt never
  /// advances [ApiaryListLoaded.page], so this re-requests the same page.
  Future<void> retryLoadNextPage() => emitLoadNextPage(reader);

  @override
  Future<void> close() {
    _refreshSubscription.cancel();
    _hiveRefreshSubscription.cancel();
    return super.close();
  }
}
