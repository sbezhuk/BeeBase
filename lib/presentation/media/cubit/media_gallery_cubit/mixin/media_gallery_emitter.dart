part of '../media_gallery_cubit.dart';

mixin MediaGalleryEmitter on Cubit<MediaGalleryState> {
  Future<String?> resolveItemDisplayPath(
    IMediaReader reader,
    LocalMediaStore localMediaStore,
    MediaGalleryItem item,
  ) async {
    final localPath = item.localFilePath;
    if (localPath != null && await File(localPath).exists()) {
      return localPath;
    }
    final attachment = item.attachment;
    if (attachment == null) {
      return null;
    }
    final result = await reader.downloadMedia(attachment.id);
    return result.fold((_) => Future.value(null), (bytes) {
      final extension = _extensionFor(attachment.originalFilename);
      return localMediaStore.save(
        Uint8List.fromList(bytes),
        id: attachment.id,
        extension: extension,
      );
    });
  }

  Future<void> emitLoad(
    IMediaReader reader,
    MediaOwnerType ownerType,
    String? ownerId,
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
    final result = await reader.getMedia(
      ownerType: ownerType,
      ownerId: ownerId,
      page: 1,
      limit: 100,
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(MediaGalleryError(failure)),
      (page) => emit(
        MediaGalleryLoaded(page.items.map(_itemFromAttachment).toList()),
      ),
    );
  }

  Future<void> emitPick(
    ImagePicker picker,
    LocalMediaStore localMediaStore,
    IMediaWriter writer,
    MediaOwnerType ownerType,
    String? ownerId,
    ImageSource source,
    VoidCallback? notifyOwnerListChanged,
  ) async {
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final localId = LocalIdGenerator.generate();
    final extension = _extensionFor(picked.name);
    final contentType = _contentTypeFor(extension);
    final localFilePath = await localMediaStore.save(
      Uint8List.fromList(bytes),
      id: localId,
      extension: extension,
    );

    final staged = MediaGalleryItem(
      localId: localId,
      localFilePath: localFilePath,
      originalFilename: picked.name,
      contentType: contentType,
      status: MediaGalleryItemStatus.staged,
    );
    _addItem(staged);

    if (ownerId == null) return;
    await _upload(writer, ownerType, ownerId, staged, notifyOwnerListChanged);
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

  Future<void> emitRemove(
    IMediaWriter writer,
    LocalMediaStore localMediaStore,
    String localId,
    VoidCallback? notifyOwnerListChanged,
  ) async {
    final current = state;
    if (current is! MediaGalleryLoaded) return;
    final item = _find(current, localId);
    if (item == null) return;

    if (item.status == MediaGalleryItemStatus.staged) {
      final path = item.localFilePath;
      if (path != null) {
        await localMediaStore.delete(path);
      }
      _removeItem(localId);
      notifyOwnerListChanged?.call();
      return;
    }

    final attachment = item.attachment;
    if (attachment == null) return;
    _updateItem(
      localId,
      (existing) => existing.copyWith(status: MediaGalleryItemStatus.removing),
    );
    final result = await writer.removeMedia(attachment.id);
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

  /// Notifies (if given) only once [item] is confirmed synced — never right
  /// after staging, before the server even has the file. Notifying earlier
  /// caused the bug this comment replaces: every `MediaGalleryCubit` for this
  /// owner type (this one included — see `MediaGalleryCubit`'s constructor)
  /// listens for that same signal and reloads from the server, and an
  /// early/premature reload here raced ahead of this very upload, replacing
  /// [item] before it had a server id and silently dropping every later
  /// `_updateItem(item.localId, ...)` call for it (no item left in the
  /// reloaded state matches that local id) — the upload still succeeded
  /// server-side, but the UI never reflected it, most visibly for a first
  /// photo (the reload's fetch came back empty, wiping the preview back to
  /// placeholder/map).
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
            status: _statusFor(attachment.syncStatus),
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
      localFilePath: attachment.localFilePath,
      originalFilename: attachment.originalFilename,
      contentType: attachment.contentType,
      status: _statusFor(attachment.syncStatus),
      attachment: attachment,
    );
  }

  MediaGalleryItemStatus _statusFor(MediaSyncStatus syncStatus) =>
      switch (syncStatus) {
        MediaSyncStatus.synced => MediaGalleryItemStatus.synced,
        MediaSyncStatus.pending => MediaGalleryItemStatus.pending,
        MediaSyncStatus.failed => MediaGalleryItemStatus.failed,
      };

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
  // "Cannot emit new states after calling close" (same class of bug
  // `ConnectivityEmitter.emitFromOnline` guards for the same reason).

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

  String _extensionFor(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == filename.length - 1) return 'jpg';
    return filename.substring(dotIndex + 1).toLowerCase();
  }

  String _contentTypeFor(String extension) => switch (extension) {
    'png' => 'image/png',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
}
