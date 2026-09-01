import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/inspection_type.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/inspection_form_state.dart';
part 'state/inspection_form_initial.dart';
part 'state/inspection_form_loading.dart';
part 'state/inspection_form_success.dart';
part 'state/inspection_form_error.dart';
part 'mixin/inspection_form_emitter.dart';

final class InspectionFormCubit extends Cubit<InspectionFormState> with InspectionFormEmitter {
  InspectionFormCubit({
    required this.writer,
    required this.hiveId,
    required this.refreshNotifier,
    this.initial,
  }) : super(const InspectionFormInitial());

  final IInspectionWriter writer;
  final String hiveId;
  final InspectionListRefreshNotifier refreshNotifier;

  /// The inspection being edited, or `null` when this form is creating a new
  /// one.
  final Inspection? initial;

  bool get isEditing => initial != null;

  Future<void> submit({
    required DateTime date,
    required InspectionType type,
    required String notes,
  }) {
    return emitSubmit(
      writer,
      refreshNotifier,
      hiveId: hiveId,
      initial: initial,
      date: date,
      type: type,
      notes: notes,
    );
  }
}
