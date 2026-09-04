import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_item.dart';
import 'package:beebase/utils/media_file_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

part 'state/media_gallery_state.dart';
part 'state/media_gallery_loading.dart';
part 'state/media_gallery_loaded.dart';
part 'state/media_gallery_error.dart';
part 'mixin/media_gallery_emitter.dart';

/// Reusable photo-attachment cubit shared by the Apiary and Hive create/edit
/// flows and the details page. [ownerId] switches between two modes at
/// construction, though a create form transitions from the first into the
/// second the moment a photo is picked (see [configureDraftCreation]):
///  - `null` — staging mode, used by a create form before the parent entity
///    exists. A pick uploads immediately once [configureDraftCreation]'s
///    callback resolves an owner id (materializing the parent as a draft if
///    needed); it's only held locally, pending [commitChanges] on submit, if
///    that callback is unset or fails to resolve one.
///  - non-null — live mode by default (the details page: picks/removes take
///    effect immediately, there's no Save to gate on), but the edit form
///    switches it into *deferred* mode via [deferChangesUntilCommit] right
///    after construction: picks/removes still update [state] immediately for
///    a responsive UI, but neither uploads nor deletes anything server-side
///    until [commitChanges] runs — called only once the form's own Save
///    succeeds — so an edit abandoned without saving never touches the
///    server, matching how every other field on that form already behaves.
final class MediaGalleryCubit extends Cubit<MediaGalleryState>
    with MediaGalleryEmitter {
  // `ownerId` stays a plain named param rather than `this._ownerId` — a
  // private name can't be spelled as a named argument from another library
  // (every call site, e.g. `di.dart`, is one), so an initializing formal
  // here would break construction from outside this file.
  // `ownerListChanges` is subscribed to immediately (rather than lazily) so
  // that a list tile's gallery cubit — created once via `BlocProvider` and
  // never rebuilt — still picks up a photo added/removed elsewhere (the
  // details page, the edit form) even while it stays off-screen behind that
  // other route. See `notifyOwnerListChanged` for the other half of this:
  // this cubit's own add/remove calls that same broadcast so every other
  // gallery for the same owner type refreshes in turn.
  MediaGalleryCubit({
    required this.reader,
    required this.writer,
    required this.ownerType,
    String? ownerId,
    ImagePicker? imagePicker,
    VoidCallback? notifyOwnerListChanged,
    Stream<void>? ownerListChanges,
    Future<List<String>> Function(String ownerId)? resolveImages,
  }) : _ownerId = ownerId, // ignore: prefer_initializing_formals
       _picker = imagePicker ?? ImagePicker(),
       // ignore: prefer_initializing_formals
       _notifyOwnerListChanged = notifyOwnerListChanged,
       // ignore: prefer_initializing_formals
       _resolveImages = resolveImages,
       super(const MediaGalleryLoading()) {
    _ownerListChangesSubscription = ownerListChanges?.listen((_) {
      // A reload while deferred would fetch the server's current attached
      // set and clobber whatever staged picks/pending removals this edit
      // session has accumulated but not yet committed.
      if (!isStaging && !_deferChanges) load();
    });
  }

  final IMediaReader reader;
  final IMediaWriter writer;
  final MediaOwnerType ownerType;
  final ImagePicker _picker;
  final VoidCallback? _notifyOwnerListChanged;

  /// Resolves the *current* set of media ids attached to whatever owner id
  /// [load] is about to fetch for — called fresh on every [load] (including
  /// the ones triggered by [ownerListChanges], not just the first) so a
  /// gallery reload always reflects the owning Apiary/Hive's latest
  /// `images`, the same way asking media-service "what's attached to owner
  /// X" always used to. DI wires this per [ownerType] to the matching
  /// `IApiaryReader.getApiary`/`IHiveReader.getHive` — apiary/hive-service
  /// is now the source of truth for "which media ids belong to me".
  final Future<List<String>> Function(String ownerId)? _resolveImages;
  StreamSubscription<void>? _ownerListChangesSubscription;

  String? _ownerId;

  /// Set by [deferChangesUntilCommit] — see the class doc's "deferred mode"
  /// paragraph.
  bool _deferChanges = false;

  /// Lets a create-mode form page supply a way to materialize the parent
  /// Apiary/Hive the first time a photo is picked, so the upload can start
  /// immediately instead of waiting for staged photos to be flushed via
  /// [commitChanges] on submit. Configured after construction (see
  /// `configureDraftCreation`) because the page's form field values it reads
  /// aren't available yet when this cubit is built.
  Future<String?> Function()? _ensureOwnerId;

  bool get isStaging => _ownerId == null;

  bool get hasStagedPhotos {
    final current = state;
    return current is MediaGalleryLoaded &&
        current.items.any(
          (item) => item.status == MediaGalleryItemStatus.staged,
        );
  }

  /// Whether [commitChanges] has anything to actually do — a staged pick, a
  /// deferred removal, or both.
  bool get hasPendingChanges => hasStagedPhotos || hasPendingRemovals;

  /// Initial load — a no-op straight to an empty list in staging mode, or a
  /// fetch of already-attached photos in live/deferred mode.
  Future<void> load() => emitLoad(reader, _ownerId, _resolveImages);

  void configureDraftCreation(Future<String?> Function() ensureOwnerId) {
    _ensureOwnerId = ensureOwnerId;
  }

  /// Switches this gallery into deferred mode (see the class doc) — called
  /// once, right after construction, by the edit form only.
  void deferChangesUntilCommit() {
    _deferChanges = true;
  }

  Future<void> pickFromGallery() => _pick(ImageSource.gallery);

  Future<void> takePhoto() => _pick(ImageSource.camera);

  Future<void> _pick(ImageSource source) async {
    final resolvedOwnerId = await emitPick(
      _picker,
      writer,
      ownerType,
      _ownerId,
      _deferChanges,
      source,
      _notifyOwnerListChanged,
      _ensureOwnerId,
    );
    if (resolvedOwnerId != null) _ownerId = resolvedOwnerId;
  }

  /// Flushes every staged pick and every deferred removal (see the class
  /// doc's "deferred mode" paragraph) against the parent Apiary/Hive's id —
  /// called by the form cubit right after a successful create/update.
  Future<void> commitChanges(MediaOwnerType ownerType, String ownerId) {
    assert(
      ownerType == this.ownerType,
      'commitChanges was called with a different owner type than this gallery was built for.',
    );
    _ownerId = ownerId;
    return emitCommitChanges(writer, ownerType, ownerId);
  }

  Future<void> remove(String localId) => emitRemove(
    writer,
    ownerType,
    _ownerId,
    localId,
    _deferChanges,
    _notifyOwnerListChanged,
  );

  Future<void> retry(String localId) =>
      emitRetry(writer, ownerType, _ownerId, localId, _notifyOwnerListChanged);

  @override
  Future<void> close() {
    unawaited(_ownerListChangesSubscription?.cancel());
    return super.close();
  }
}
