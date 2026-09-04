import 'package:beebase/core/networking/network_info.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_cubit.dart';
import 'package:beebase/presentation/media/cubit/media_gallery_cubit/media_gallery_item.dart';
import 'package:beebase/presentation/media/widget/media_thumbnail.dart';
import 'package:beebase/presentation/widgets/confirmation_sheet/confirmation_sheet.dart';
import 'package:beebase/utils/di.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:beebase/utils/extensions/theme_text_styles.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


part 'media_gallery_section/media_gallery_add_tile.dart';
part 'media_gallery_section/media_gallery_item_tile.dart';
part 'media_gallery_section/media_gallery_picker_sheet.dart';

/// Shared photo strip reused, unmodified, across the Apiary and Hive
/// create/edit forms and details pages — one `BlocBuilder` over the ambient
/// `MediaGalleryCubit` (provided by the page). See the plan's "Reusable
/// picker + gallery component" section.
final class MediaGallerySection extends StatelessWidget {
  const MediaGallerySection({super.key});

  static const _tileSize = 88.0;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return BlocBuilder<MediaGalleryCubit, MediaGalleryState>(
      builder: (context, state) {
        final items = state is MediaGalleryLoaded ? state.items : const <MediaGalleryItem>[];
        final isLoading = state is MediaGalleryLoading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('media.gallery.title'.tr(), style: context.textStyles.label.copyWith(color: context.colors.honey.muted)),
            SizedBox(height: spacing.xs),
            SizedBox(
              height: _tileSize,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length + 1,
                separatorBuilder: (context, index) => SizedBox(width: spacing.sm),
                itemBuilder: (context, index) {
                  if (index == items.length) {
                    return _MediaGalleryAddTile(size: _tileSize, isLoading: isLoading);
                  }
                  return _MediaGalleryItemTile(item: items[index], size: _tileSize);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
