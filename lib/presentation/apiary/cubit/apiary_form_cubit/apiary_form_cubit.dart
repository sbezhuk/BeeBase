import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/apiary_form_state.dart';
part 'state/apiary_form_initial.dart';
part 'state/apiary_form_loading.dart';
part 'state/apiary_form_success.dart';
part 'state/apiary_form_error.dart';
part 'mixin/apiary_form_emitter.dart';

final class ApiaryFormCubit extends Cubit<ApiaryFormState>
    with ApiaryFormEmitter {
  ApiaryFormCubit({
    required this.writer,
    required this.refreshNotifier,
    this.initial,
  }) : super(const ApiaryFormInitial());

  final IApiaryWriter writer;
  final ApiaryListRefreshNotifier refreshNotifier;

  /// The apiary being edited, or `null` when this form is creating a new one.
  final Apiary? initial;

  bool get isEditing => initial != null;

  Future<void> submit({
    required String name,
    String? description,
    String? location,
  }) {
    return emitSubmit(
      writer,
      refreshNotifier,
      initial: initial,
      name: name,
      description: description,
      location: location,
    );
  }
}
