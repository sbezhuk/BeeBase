import 'package:beebase/core/location/location_failure.dart';
import 'package:beebase/core/location/location_service.dart';
import 'package:beebase/core/location/resolved_location.dart';
import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/apiary_writer.dart';
import 'package:beebase/presentation/apiary/apiary_list_refresh_notifier.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/utils/either.dart';
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
    required this.locationService,
    this.initial,
  }) : super(const ApiaryFormInitial());

  final IApiaryWriter writer;
  final ApiaryListRefreshNotifier refreshNotifier;
  final LocationService locationService;

  /// The apiary being edited, or `null` when this form is creating a new one.
  final Apiary? initial;

  /// The apiary materialized early by [ensureDraft] — the first photo picked
  /// during a create flow triggers this, well before [submit] runs. `submit`
  /// updates this record instead of creating a second one. Stays `null` for
  /// the edit flow, and for a create flow with no photos.
  Apiary? _draft;

  bool get isEditing => initial != null;

  /// Called by [MediaGalleryCubit] (via `configureDraftCreation`) the first
  /// time a photo is picked in a create flow, so the photo has a real (or
  /// local-offline) owner id to upload against immediately instead of
  /// waiting for [submit]. Idempotent — a second photo reuses the same
  /// draft rather than creating another apiary. Returns `null` on failure,
  /// leaving the photo staged so it's still picked up by [submit].
  Future<String?> ensureDraft({
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
  }) async {
    final existing = _draft;
    if (existing != null) return existing.id;
    final result = await writer.createApiary(
      name: name,
      description: description,
      location: location,
      lat: lat,
      lon: lon,
    );
    return result.fold((_) => null, (apiary) {
      _draft = apiary;
      return apiary.id;
    });
  }

  /// [mediaGalleryCubit] is optional so this method's existing callers/tests
  /// don't need to know about media at all — when given, any photos still
  /// staged in it (i.e. not already uploaded against [_draft] by
  /// [ensureDraft]) get attached to the just-created/-updated apiary right
  /// after a successful submit (see [ApiaryFormEmitter.emitSubmit]).
  Future<void> submit({
    required String name,
    String? description,
    String? location,
    double? lat,
    double? lon,
    MediaGalleryCubit? mediaGalleryCubit,
  }) {
    return emitSubmit(
      writer,
      refreshNotifier,
      mediaGalleryCubit,
      initial: initial ?? _draft,
      name: name,
      description: description,
      location: location,
      lat: lat,
      lon: lon,
    );
  }

  /// Resolves the device's current position to a display address, for the
  /// "use current location" action. Kept out of [ApiaryFormState] since it's
  /// a local, ephemeral concern for the location field, not the form's
  /// submit lifecycle.
  Future<Either<LocationFailure, ResolvedLocation>> resolveCurrentLocation() {
    return locationService.getCurrentLocation();
  }
}
