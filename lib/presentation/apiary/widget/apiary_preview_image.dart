import 'package:beebase/domain/entity/apiary.dart';
import 'package:beebase/domain/enum/apiary_sync_status.dart';
import 'package:beebase/presentation/apiary/widget/apiary_map_photo.dart';
import 'package:beebase/presentation/apiary/widget/apiary_photo_placeholder.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/media/widget/media_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The hero photo slot shared by the list tile and the details page: the
/// first attached photo if [apiary] has any, otherwise the existing
/// map/placeholder fallback. Reads an ambient [MediaGalleryCubit] for
/// [apiary] rather than creating its own — the caller owns providing that
/// (once, per CLAUDE.md's "avoid duplicate cubit creation" rule), since the
/// details page already needs one for its photo gallery section too.
final class ApiaryPreviewImage extends StatelessWidget {
  const ApiaryPreviewImage({
    required this.apiary,
    required this.height,
    super.key,
  });

  final Apiary apiary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final galleryState = context.watch<MediaGalleryCubit>().state;
    if (galleryState is MediaGalleryLoaded && galleryState.items.isNotEmpty) {
      return MediaThumbnail(
        item: galleryState.items.first,
        width: double.infinity,
        height: height,
        borderRadius: BorderRadius.zero,
      );
    }

    return ApiaryMapPhoto(
      latitude: apiary.lat,
      longitude: apiary.lon,
      height: height,
      fallback: apiary.syncStatus == ApiarySyncStatus.synced
          ? ApiaryPhotoPlaceholder(height: height)
          : ApiaryPhotoPlaceholder(
              height: height,
              titleKey: 'apiary.offlinePhotoPlaceholder.title',
              subtitleKey: 'apiary.offlinePhotoPlaceholder.subtitle',
            ),
    );
  }
}
