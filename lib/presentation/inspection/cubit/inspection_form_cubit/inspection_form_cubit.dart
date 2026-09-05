import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/inspection.dart';
import 'package:beebase/domain/enum/backend/inspection_type.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/inspection_writer.dart';
import 'package:beebase/presentation/inspection/inspection_list_refresh_notifier.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'state/inspection_form_state.dart';
part 'state/inspection_form_initial.dart';
part 'state/inspection_form_loading.dart';
part 'state/inspection_form_success.dart';
part 'state/inspection_form_error.dart';
part 'mixin/inspection_form_emitter.dart';

final class InspectionFormCubit extends Cubit<InspectionFormState> with InspectionFormEmitter {
  InspectionFormCubit({required this.writer, required this.hiveId, required this.refreshNotifier, this.initial})
    : super(const InspectionFormInitial());

  final IInspectionWriter writer;
  final String hiveId;
  final InspectionListRefreshNotifier refreshNotifier;

  /// The inspection being edited, or `null` when this form is creating a new
  /// one.
  final Inspection? initial;

  /// The inspection materialized early by [ensureDraft] — the first photo
  /// picked during a create flow triggers this, well before [submit] runs.
  /// `submit` updates this record instead of creating a second one. Stays
  /// `null` for the edit flow, and for a create flow with no photos.
  Inspection? _draft;

  bool get isEditing => initial != null;

  /// Called by [MediaGalleryCubit] (via `configureDraftCreation`) the first
  /// time a photo is picked in a create flow, so the photo has a real owner
  /// id to upload against immediately instead of waiting for [submit].
  /// Idempotent — a second photo reuses the same draft rather than creating
  /// another inspection. Returns `null` on failure, leaving the photo staged
  /// so it's still picked up by [submit].
  Future<String?> ensureDraft({required DateTime date, required InspectionType type, required String notes}) async {
    final existing = _draft;
    if (existing != null) return existing.id;
    final result = await writer.createInspection(hiveId: hiveId, date: date, type: type, notes: notes);
    return result.fold((_) => null, (inspection) {
      _draft = inspection;
      return inspection.id;
    });
  }

  /// [mediaGalleryCubit] is optional so this method's existing callers/tests
  /// don't need to know about media at all — when given, any photos still
  /// staged in it (i.e. not already uploaded against [_draft] by
  /// [ensureDraft]) get attached to the just-created/-updated inspection
  /// right after a successful submit (see
  /// [InspectionFormEmitter.emitSubmit]).
  Future<void> submit({
    required DateTime date,
    required InspectionType type,
    required String notes,
    MediaGalleryCubit? mediaGalleryCubit,
  }) {
    return emitSubmit(
      writer,
      refreshNotifier,
      mediaGalleryCubit,
      hiveId: hiveId,
      initial: initial ?? _draft,
      date: date,
      type: type,
      notes: notes,
    );
  }
}
