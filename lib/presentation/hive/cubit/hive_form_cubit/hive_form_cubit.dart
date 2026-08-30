import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/hive_form_state.dart';
part 'state/hive_form_initial.dart';
part 'state/hive_form_loading.dart';
part 'state/hive_form_success.dart';
part 'state/hive_form_error.dart';
part 'mixin/hive_form_emitter.dart';

final class HiveFormCubit extends Cubit<HiveFormState> with HiveFormEmitter {
  HiveFormCubit({
    required this.writer,
    required this.apiaryId,
    required this.refreshNotifier,
    this.initial,
  }) : super(const HiveFormInitial());

  final IHiveWriter writer;
  final String apiaryId;
  final HiveListRefreshNotifier refreshNotifier;

  /// The hive being edited, or `null` when this form is creating a new one.
  final Hive? initial;

  bool get isEditing => initial != null;

  Future<void> submit({required String name, String? description}) {
    return emitSubmit(
      writer,
      refreshNotifier,
      apiaryId: apiaryId,
      initial: initial,
      name: name,
      notes: description,
    );
  }
}
