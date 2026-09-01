import 'package:beebase/core/storage/local_media_store.dart';
import 'package:beebase/domain/enum/backend/media_owner_type.dart';
import 'package:beebase/domain/repositories/media_reader.dart';
import 'package:beebase/domain/repositories/media_writer.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_item.dart';
import 'package:beebase/presentation/media/widget/media_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMediaReader extends Mock implements IMediaReader {}

class MockMediaWriter extends Mock implements IMediaWriter {}

void main() {
  testWidgets(
    'rebuilding in place with a new item (same slot, different localId — '
    'exactly what happens when MediaGalleryCubit.load() rebuilds its list '
    'from the server after an offline photo finishes syncing, reassigning '
    'localId from the local placeholder to the server id) does not throw '
    '"setState() callback argument returned a Future"',
    timeout: const Timeout(Duration(seconds: 20)),
    (tester) async {
      // Deliberately non-existent paths: this regression is about
      // `didUpdateWidget`'s setState call itself, which fires (and, before
      // the fix, throws) regardless of whether the resolved path ever turns
      // into a real rendered image — no need for real files or an actual
      // decodable image here, only for `File(path).exists()` to resolve
      // (quickly, either way) so `_pathFuture` settles.
      final cubit = MediaGalleryCubit(
        reader: MockMediaReader(),
        writer: MockMediaWriter(),
        localMediaStore: const LocalMediaStore(),
        ownerType: MediaOwnerType.apiary,
        ownerId: 'apiary-1',
      );

      const itemA = MediaGalleryItem(
        localId: 'local-placeholder-1',
        localFilePath: '/tmp/media_thumbnail_test_nonexistent_a.jpg',
        originalFilename: 'a.jpg',
        contentType: 'image/jpeg',
        status: MediaGalleryItemStatus.pending,
      );

      Widget host(MediaGalleryItem item) {
        return MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: Scaffold(body: MediaThumbnail(item: item)),
          ),
        );
      }

      await tester.pumpWidget(host(itemA));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      // The server-synced replacement: same slot in the tree, but a
      // different localId (and localFilePath) — matches what
      // `_itemFromAttachment` produces once `MediaGalleryCubit.load()`
      // re-reads the cache after `MediaOperationHandler` reconciles a synced
      // photo under its new server id (see
      // `MediaRepositoryImpl._itemFromAttachment`). This is the transition
      // that fires `didUpdateWidget`'s changed-item branch.
      const itemB = MediaGalleryItem(
        localId: 'server-media-1',
        localFilePath: '/tmp/media_thumbnail_test_nonexistent_b.jpg',
        originalFilename: 'b.jpg',
        contentType: 'image/jpeg',
        status: MediaGalleryItemStatus.synced,
      );

      await tester.pumpWidget(host(itemB));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);

      await cubit.close();
    },
  );
}
