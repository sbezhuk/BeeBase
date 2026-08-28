import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_reader.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/apiary_list_state.dart';
part 'state/apiary_list_loading.dart';
part 'state/apiary_list_loaded.dart';
part 'state/apiary_list_error.dart';
part 'mixin/apiary_list_emitter.dart';

final class ApiaryListCubit extends Cubit<ApiaryListState> with ApiaryListEmitter {
  ApiaryListCubit({required this.reader, required this.refreshNotifier}) : super(const ApiaryListLoading()) {
    _refreshSubscription = refreshNotifier.onChanged.listen((_) => refresh());
  }

  final IApiaryReader reader;
  final ApiaryListRefreshNotifier refreshNotifier;
  late final StreamSubscription<void> _refreshSubscription;

  /// Initial/forced load — replaces the body with a full-screen spinner.
  Future<void> loadApiaries() => emitLoadApiaries(reader);

  /// Pull-to-refresh — keeps the current list visible while refetching.
  Future<void> refresh() => emitRefreshApiaries(reader);

  @override
  Future<void> close() {
    _refreshSubscription.cancel();
    return super.close();
  }
}
