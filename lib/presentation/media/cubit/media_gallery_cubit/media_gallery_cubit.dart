import 'dart:async';
import 'dart:io';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/core/offline/local_id_generator.dart';
import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/domain/entity/media_attachment.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/enum/local/media_sync_status.dart';
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
/// flows. [ownerId] switches between two modes at construction, though a
/// create form transitions from the first into the second the moment a
/// photo is picked (see [configureDraftCreation]):
///  - `null` — staging mode, used by a create form before the parent entity
///    exists. A pick uploads immediately once [configureDraftCreation]'s
///    callback resolves an owner id (materializing the parent as a draft if
///    needed); it's only held locally, pending [attachTo] on submit, if that
///    callback is unset or fails to resolve one.
///  - non-null — live mode, used by the edit form and the details page.
///    Picks upload/attach immediately.
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
    required this.localMediaStore,
    required this.ownerType,
    String? ownerId,
    ImagePicker? imagePicker,
    VoidCallback? notifyOwnerListChanged,
    Stream<void>? ownerListChanges,
  }) : _ownerId = ownerId, // ignore: prefer_initializing_formals
       _picker = imagePicker ?? ImagePicker(),
       // ignore: prefer_initializing_formals
       _notifyOwnerListChanged = notifyOwnerListChanged,
       super(const MediaGalleryLoading()) {
    _ownerListChangesSubscription = ownerListChanges?.listen((_) {
      if (!isStaging) load();
    });
  }

  final IMediaReader reader;
  final IMediaWriter writer;
  final LocalMediaStore localMediaStore;
  final MediaOwnerType ownerType;
  final ImagePicker _picker;
  final VoidCallback? _notifyOwnerListChanged;
  StreamSubscription<void>? _ownerListChangesSubscription;

  String? _ownerId;

  /// Lets a create-mode form page supply a way to materialize the parent
  /// Apiary/Hive — as a real or local-offline id — the first time a photo
  /// is picked, so the upload can start immediately instead of waiting for
  /// staged photos to be flushed via [attachTo] on submit. Configured after
  /// construction (see `configureDraftCreation`) because the page's form
  /// field values it reads aren't available yet when this cubit is built.
  Future<String?> Function()? _ensureOwnerId;

  bool get isStaging => _ownerId == null;

  bool get hasStagedPhotos {
    final current = state;
    return current is MediaGalleryLoaded &&
        current.items.any(
          (item) => item.status == MediaGalleryItemStatus.staged,
        );
  }

  /// Initial load — a no-op straight to an empty list in staging mode, or a
  /// fetch of already-attached photos in live mode.
  Future<void> load() => emitLoad(reader, ownerType, _ownerId);

  void configureDraftCreation(Future<String?> Function() ensureOwnerId) {
    _ensureOwnerId = ensureOwnerId;
  }

  Future<void> pickFromGallery() => _pick(ImageSource.gallery);

  Future<void> takePhoto() => _pick(ImageSource.camera);

  Future<void> _pick(ImageSource source) async {
    final resolvedOwnerId = await emitPick(
      _picker,
      localMediaStore,
      writer,
      ownerType,
      _ownerId,
      source,
      _notifyOwnerListChanged,
      _ensureOwnerId,
    );
    if (resolvedOwnerId != null) _ownerId = resolvedOwnerId;
  }

  /// Flushes every staged file through [IMediaWriter.attachMedia] once the
  /// parent Apiary/Hive this gallery belongs to has a real (or
  /// local-offline) id — called by the form cubit right after a successful
  /// create.
  Future<void> attachTo(MediaOwnerType ownerType, String ownerId) {
    assert(
      ownerType == this.ownerType,
      'attachTo was called with a different owner type than this gallery was built for.',
    );
    _ownerId = ownerId;
    return emitAttachStaged(writer, ownerType, ownerId);
  }

  Future<void> remove(String localId) =>
      emitRemove(writer, localMediaStore, localId, _notifyOwnerListChanged);

  Future<void> retry(String localId) =>
      emitRetry(writer, ownerType, _ownerId, localId, _notifyOwnerListChanged);

  /// The local file path [MediaThumbnail] should render [item] from — its
  /// own [MediaGalleryItem.localFilePath] if that file still exists, or a
  /// freshly downloaded (and disk-cached) copy otherwise. `null` means the
  /// download failed and the caller should show a broken-image state.
  Future<String?> resolveDisplayPath(MediaGalleryItem item) =>
      resolveItemDisplayPath(reader, localMediaStore, item);

  @override
  Future<void> close() {
    unawaited(_ownerListChangesSubscription?.cancel());
    return super.close();
  }
}
