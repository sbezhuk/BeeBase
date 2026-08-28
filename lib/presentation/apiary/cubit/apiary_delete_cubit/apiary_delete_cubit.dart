import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/apiary_delete_state.dart';
part 'state/apiary_delete_initial.dart';
part 'state/apiary_delete_loading.dart';
part 'state/apiary_delete_success.dart';
part 'state/apiary_delete_error.dart';
part 'mixin/apiary_delete_emitter.dart';

/// Owns [ApiaryDetailsPage]'s delete action. The apiary itself is handed in
/// at construction (the caller already has it, e.g. from the list) so this
/// cubit only needs to model the delete request's lifecycle.
final class ApiaryDeleteCubit extends Cubit<ApiaryDeleteState> with ApiaryDeleteEmitter {
  ApiaryDeleteCubit({required this.writer, required this.apiary, required this.refreshNotifier})
    : super(const ApiaryDeleteInitial());

  final IApiaryWriter writer;
  final Apiary apiary;
  final ApiaryListRefreshNotifier refreshNotifier;

  Future<void> delete() => emitDelete(writer, refreshNotifier, apiary.id);
}
