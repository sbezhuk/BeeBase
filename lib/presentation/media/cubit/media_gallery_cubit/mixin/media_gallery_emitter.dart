part of '../media_gallery_cubit.dart';

mixin MediaGalleryEmitter on Cubit<MediaGalleryState> {
  /// Ids of already-attached photos the user removed while `deferChanges`
  /// was on (the edit form) — hidden from [state] immediately for a
  /// responsive UI, but not actually deleted server-side until
  /// [emitCommitChanges] runs. Dropped for good (never deleted) if the form
  /// is abandoned without saving, since this cubit — and this field with it
  /// — is torn down along with the page.
  final Set<String> _pendingRemovalIds = {};

  /// Distinguishes two picks made within the same microsecond, so every
  /// staged item's [MediaGalleryItem.localId] is unique for the lifetime of
  /// this cubit.
  int _stagedSequence = 0;

  bool get hasPendingRemovals => _pendingRemovalIds.isNotEmpty;

  Future<void> emitLoad(
    IMediaReader reader,
    String? ownerId,
    Future<List<String>> Function(String ownerId)? resolveImages,
  ) async {
    if (ownerId == null) {
      emit(const MediaGalleryLoaded([]));
      return;
    }
    // Only the true first load shows the loading frame. `load()` is also
    // what runs on every `ownerListChanges` signal — including the one this
    // same cubit's own successful upload/remove just fired at itself (see
    // `notifyOwnerListChanged` wiring in `di.dart`) — and re-emitting
    // `MediaGalleryLoading` there would blank out the gallery/preview that's
    // already showing correct data for a moment, a visible flash on every
    // add. A state already `MediaGalleryLoaded` means there's something on
    // screen worth keeping up while this refetch runs in the background.
    if (state is! MediaGalleryLoaded) {
      emit(const MediaGalleryLoading());
    }
    final ids = resolveImages == null
        ? const <String>[]
        : await resolveImages(ownerId);
    if (isClosed) return;
    final result = await reader.getMedia(ids: ids);
    if (isClosed) return;
    result.fold(
      (failure) => emit(MediaGalleryError(failure)),
      (items) =>
          emit(MediaGalleryLoaded(items.map(_itemFromAttachment).toList())),
    );
  }

  /// Returns the owner id the picked photo ended up (attempting to be)
  /// uploaded against — `ownerId` unchanged if it was already non-null,
  /// whatever [ensureOwnerId] resolved to if it wasn't, or `null` if the
  /// pick was cancelled or no owner could be materialized yet (the photo
  /// stays `staged` in that case, to be flushed by [emitAttachStaged] once
  /// the form is submitted). The caller is responsible for remembering a
  /// non-null result so later picks in the same session skip straight to
  /// live mode.
  ///
  /// When [deferChanges] is on (the edit form — `ownerId` is already known,
  /// unlike the create form's staging-until-a-draft-exists window), the pick
  /// always stays `staged` and this returns `ownerId` unchanged without
  /// uploading anything — [emitCommitChanges] is what actually uploads it,
  /// called only once the form's own Save succeeds, so a picked photo never
  /// reaches the server for an edit the user abandons.
  Future<String?> emitPick(
    ImagePicker picker,
    IMediaWriter writer,
    MediaOwnerType ownerType,
    String? ownerId,
    bool deferChanges,
    ImageSource source,
    VoidCallback? notifyOwnerListChanged,
    Future<String?> Function()? ensureOwnerId,
  ) async {
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final extension = extensionFromFilename(picked.name);
    final staged = MediaGalleryItem(
      localId: 'staged-${DateTime.now().microsecondsSinceEpoch}-${_stagedSequence++}',
      // The picker's own temp file — uploaded straight from there, and only
      // ever read to render the tile until that upload finishes.
      localFilePath: picked.path,
      originalFilename: picked.name,
      contentType: contentTypeFromExtension(extension),
      status: MediaGalleryItemStatus.staged,
    );
    _addItem(staged);

    if (deferChanges) return ownerId;

    final resolvedOwnerId = ownerId ?? await ensureOwnerId?.call();
    if (resolvedOwnerId == null) return null;

    await _upload(
      writer,
      ownerType,
      resolvedOwnerId,
      staged,
      notifyOwnerListChanged,
    );
    return resolvedOwnerId;
  }

  /// No [notifyOwnerListChanged] of its own — called right after a
  /// successful create, and the form cubit already calls its own
  /// list-refresh notifier once the whole submit (entity + every staged
  /// photo) finishes, so notifying per-photo here would just be redundant.
  Future<void> emitAttachStaged(
    IMediaWriter writer,
    MediaOwnerType ownerType,
    String ownerId,
  ) async {
    final current = state;
    if (current is! MediaGalleryLoaded) return;
    final staged = current.items
        .where((item) => item.status == MediaGalleryItemStatus.staged)
        .toList();
    for (final item in staged) {
      await _upload(writer, ownerType, ownerId, item, null);
    }
  }

  /// Flushes everything accumulated while `deferChanges` was on: uploads and
  /// attaches every still-`staged` pick (via [emitAttachStaged]), then
  /// deletes every photo the user removed during that same window (see
  /// [_pendingRemovalIds]) — called once by the owning form cubit right
  /// after a successful create/update. A removal failure here is silently
  /// dropped rather than surfaced: the form has already succeeded and its
  /// page is on its way out, so there's no tile left to show a retry on —
  /// the photo simply stays attached server-side until removed again from
  /// the details page.
  Future<void> emitCommitChanges(
    IMediaWriter writer,
    MediaOwnerType ownerType,
    String ownerId,
  ) async {
    await emitAttachStaged(writer, ownerType, ownerId);
    final pending = _pendingRemovalIds.toList();
    _pendingRemovalIds.clear();
    for (final id in pending) {
      await writer.removeMedia(ownerType: ownerType, ownerId: ownerId, id: id);
    }
  }

  Future<void> emitRetry(
    IMediaWriter writer,
    MediaOwnerType ownerType,
    String? ownerId,
    String localId,
    VoidCallback? notifyOwnerListChanged,
  ) async {
    final current = state;
    if (current is! MediaGalleryLoaded || ownerId == null) return;
    final item = _find(current, localId);
    if (item == null) return;
    await _upload(writer, ownerType, ownerId, item, notifyOwnerListChanged);
  }

  /// When [deferChanges] is on (the edit form) and [localId] identifies an
  /// already-attached photo, the actual delete is deferred: the item just
  /// disappears from [state] immediately (so the UI reacts exactly as it
  /// always has) while its id is remembered in [_pendingRemovalIds] for
  /// [emitCommitChanges] to actually delete once the form's Save succeeds —
  /// so removing a photo during an edit the user abandons never reaches the
  /// server. A `staged` item (picked but never uploaded, deferred or not)
  /// always just drops locally — there's nothing server-side to defer.
  Future<void> emitRemove(
    IMediaWriter writer,
    MediaOwnerType ownerType,
    String? ownerId,
    String localId,
    bool deferChanges,
    VoidCallback? notifyOwnerListChanged,
  ) async {
    final current = state;
    if (current is! MediaGalleryLoaded) return;
    final item = _find(current, localId);
    if (item == null) return;

    if (item.status == MediaGalleryItemStatus.staged) {
      _removeItem(localId);
      notifyOwnerListChanged?.call();
      return;
    }

    final attachment = item.attachment;
    if (attachment == null || ownerId == null) return;

    if (deferChanges) {
      _pendingRemovalIds.add(attachment.id);
      _removeItem(localId);
      return;
    }

    _updateItem(
      localId,
      (existing) => existing.copyWith(status: MediaGalleryItemStatus.removing),
    );
    final result = await writer.removeMedia(
      ownerType: ownerType,
      ownerId: ownerId,
      id: attachment.id,
    );
    result.fold(
      (failure) => _updateItem(
        localId,
        (existing) => existing.copyWith(
          status: MediaGalleryItemStatus.failed,
          errorMessage: failure.message.resolve(),
        ),
      ),
      (_) {
        _removeItem(localId);
        notifyOwnerListChanged?.call();
      },
    );
  }

  /// Notifies (if given) only once [item] is confirmed uploaded and
  /// attached — never right after staging, before the server even has the
  /// file. Notifying earlier caused the bug this comment replaces: every
  /// `MediaGalleryCubit` for this owner type (this one included — see
  /// `MediaGalleryCubit`'s constructor) listens for that same signal and
  /// reloads from the server, and an early/premature reload here raced ahead
  /// of this very upload, replacing [item] before it had a server id and
  /// silently dropping every later `_updateItem(item.localId, ...)` call for
  /// it (no item left in the reloaded state matches that local id) — the
  /// upload still succeeded server-side, but the UI never reflected it, most
  /// visibly for a first photo (the reload's fetch came back empty, wiping
  /// the preview back to placeholder/map).
  Future<void> _upload(
    IMediaWriter writer,
    MediaOwnerType ownerType,
    String ownerId,
    MediaGalleryItem item,
    VoidCallback? notifyOwnerListChanged,
  ) async {
    final localFilePath = item.localFilePath;
    if (localFilePath == null) return;
    _updateItem(
      item.localId,
      (existing) => existing.copyWith(
        status: MediaGalleryItemStatus.uploading,
        uploadProgress: 0,
        clearError: true,
      ),
    );

    final result = await writer.attachMedia(
      ownerType: ownerType,
      ownerId: ownerId,
      localFilePath: localFilePath,
      originalFilename: item.originalFilename,
      contentType: item.contentType,
      onProgress: (progress) => _updateItem(
        item.localId,
        (existing) => existing.copyWith(uploadProgress: progress),
      ),
    );

    result.fold(
      (failure) => _updateItem(
        item.localId,
        (existing) => existing.copyWith(
          status: MediaGalleryItemStatus.failed,
          errorMessage: failure.message.resolve(),
        ),
      ),
      (attachment) {
        _updateItem(
          item.localId,
          (existing) => existing.copyWith(
            status: MediaGalleryItemStatus.synced,
            attachment: attachment,
            uploadProgress: null,
            clearError: true,
          ),
        );
        notifyOwnerListChanged?.call();
      },
    );
  }

  MediaGalleryItem _itemFromAttachment(MediaAttachment attachment) {
    return MediaGalleryItem(
      localId: attachment.id,
      // Carry the local file path so CachedMediaImage can render offline photos
      // (those with no imageUrl yet) even after the gallery reloads from the DB.
      localFilePath: attachment.localFilePath,
      originalFilename: attachment.originalFilename,
      contentType: attachment.contentType,
      status: MediaGalleryItemStatus.synced,
      attachment: attachment,
    );
  }

  MediaGalleryItem? _find(MediaGalleryLoaded state, String localId) {
    for (final item in state.items) {
      if (item.localId == localId) return item;
    }
    return null;
  }

  // Every one of these three is the tail end of an `await`ed pick/upload/
  // remove call (see `emitPick`/`_upload`/`emitRemove` above) — the widget
  // that owns this cubit (an Apiary/Hive form or details page) can be popped
  // while that await is in flight, closing the cubit before the callback
  // resumes. The underlying repository call (already awaited by the time we
  // get here) has completed its actual work regardless — only the now-moot
  // UI state update needs to become a no-op instead of throwing
  // "Cannot emit new states after calling close".

  void _addItem(MediaGalleryItem item) {
    if (isClosed) return;
    final current = state;
    final items = current is MediaGalleryLoaded
        ? current.items
        : const <MediaGalleryItem>[];
    emit(MediaGalleryLoaded([...items, item]));
  }

  void _updateItem(
    String localId,
    MediaGalleryItem Function(MediaGalleryItem current) update,
  ) {
    if (isClosed) return;
    final current = state;
    if (current is! MediaGalleryLoaded) return;
    emit(
      MediaGalleryLoaded([
        for (final item in current.items)
          if (item.localId == localId) update(item) else item,
      ]),
    );
  }

  void _removeItem(String localId) {
    if (isClosed) return;
    final current = state;
    if (current is! MediaGalleryLoaded) return;
    emit(
      MediaGalleryLoaded(
        current.items.where((item) => item.localId != localId).toList(),
      ),
    );
  }
}
