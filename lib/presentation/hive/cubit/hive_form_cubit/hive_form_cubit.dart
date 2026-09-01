import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/hive.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/hive_writer.dart';
import 'package:beebase/presentation/hive/hive_list_refresh_notifier.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/hive_form_state.dart';
part 'state/hive_form_initial.dart';
part 'state/hive_form_loading.dart';
part 'state/hive_form_success.dart';
part 'state/hive_form_error.dart';
part 'mixin/hive_form_emitter.dart';

final class HiveFormCubit extends Cubit<HiveFormState> with HiveFormEmitter {
  HiveFormCubit({required this.writer, required this.apiaryId, required this.refreshNotifier, this.initial})
    : super(const HiveFormInitial());

  final IHiveWriter writer;
  final String apiaryId;
  final HiveListRefreshNotifier refreshNotifier;

  /// The hive being edited, or `null` when this form is creating a new one.
  final Hive? initial;

  bool get isEditing => initial != null;

  /// [mediaGalleryCubit] is optional so this method's existing callers/tests
  /// don't need to know about media at all — when given, any photos staged
  /// in it get attached to the just-created/-updated hive right after a
  /// successful submit (see [HiveFormEmitter.emitSubmit]).
  Future<void> submit({required String name, String? description, MediaGalleryCubit? mediaGalleryCubit}) {
    return emitSubmit(
      writer,
      refreshNotifier,
      mediaGalleryCubit,
      apiaryId: apiaryId,
      initial: initial,
      name: name,
      notes: description,
    );
  }
}
