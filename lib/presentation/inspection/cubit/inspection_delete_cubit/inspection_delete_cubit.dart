import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/inspection_delete_state.dart';
part 'state/inspection_delete_initial.dart';
part 'state/inspection_delete_loading.dart';
part 'state/inspection_delete_success.dart';
part 'state/inspection_delete_error.dart';
part 'mixin/inspection_delete_emitter.dart';

/// Owns [InspectionDetailsPage]'s delete action. The inspection itself is
/// handed in at construction (the caller already has it, e.g. from the
/// list) so this cubit only needs to model the delete request's lifecycle.
final class InspectionDeleteCubit extends Cubit<InspectionDeleteState>
    with InspectionDeleteEmitter {
  InspectionDeleteCubit({
    required this.writer,
    required this.inspection,
    required this.refreshNotifier,
  }) : super(const InspectionDeleteInitial());

  final IInspectionWriter writer;
  final Inspection inspection;
  final InspectionListRefreshNotifier refreshNotifier;

  Future<void> delete() =>
      emitDelete(writer, refreshNotifier, hiveId: inspection.hiveId, id: inspection.id);
}
