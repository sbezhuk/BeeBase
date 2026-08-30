import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/hive_delete_state.dart';
part 'state/hive_delete_initial.dart';
part 'state/hive_delete_loading.dart';
part 'state/hive_delete_success.dart';
part 'state/hive_delete_error.dart';
part 'mixin/hive_delete_emitter.dart';

/// Owns [HiveDetailsPage]'s delete action. The hive itself is handed in at
/// construction (the caller already has it, e.g. from the list) so this
/// cubit only needs to model the delete request's lifecycle.
final class HiveDeleteCubit extends Cubit<HiveDeleteState>
    with HiveDeleteEmitter {
  HiveDeleteCubit({
    required this.writer,
    required this.hive,
    required this.refreshNotifier,
  }) : super(const HiveDeleteInitial());

  final IHiveWriter writer;
  final Hive hive;
  final HiveListRefreshNotifier refreshNotifier;

  Future<void> delete() => emitDelete(writer, refreshNotifier, hive.id);
}
