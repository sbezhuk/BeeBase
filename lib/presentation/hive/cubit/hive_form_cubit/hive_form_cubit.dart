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

  /// The hive materialized early by [ensureDraft] — the first photo picked
  /// during a create flow triggers this, well before [submit] runs. `submit`
  /// updates this record instead of creating a second one. Stays `null` for
  /// the edit flow, and for a create flow with no photos.
  Hive? _draft;

  bool get isEditing => initial != null;

  /// Called by [MediaGalleryCubit] (via `configureDraftCreation`) the first
  /// time a photo is picked in a create flow, so the photo has a real owner
  /// id to upload against immediately instead of waiting for [submit].
  /// Idempotent — a second photo reuses the same draft rather than creating
  /// another hive. Returns `null` on failure, leaving the photo staged so
  /// it's still picked up by [submit].
  Future<String?> ensureDraft({required String name, String? notes}) async {
    final existing = _draft;
    if (existing != null) return existing.id;
    final result = await writer.createHive(
      apiaryId: apiaryId,
      name: name,
      notes: notes,
    );
    return result.fold((_) => null, (hive) {
      _draft = hive;
      return hive.id;
    });
  }

  /// [mediaGalleryCubit] is optional so this method's existing callers/tests
  /// don't need to know about media at all — when given, any photos still
  /// staged in it (i.e. not already uploaded against [_draft] by
  /// [ensureDraft]) get attached to the just-created/-updated hive right
  /// after a successful submit (see [HiveFormEmitter.emitSubmit]).
  Future<void> submit({
    required String name,
    String? description,
    MediaGalleryCubit? mediaGalleryCubit,
  }) {
    return emitSubmit(
      writer,
      refreshNotifier,
      mediaGalleryCubit,
      apiaryId: apiaryId,
      initial: initial ?? _draft,
      name: name,
      notes: description,
    );
  }
}
