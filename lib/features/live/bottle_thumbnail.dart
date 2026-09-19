import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/tasting_item.dart';

/// Where a glass's photo lives on *this* device, if it has been downloaded.
///
/// Records have value equality, so this family is keyed by the identity of the
/// image rather than by the item object — a re-fetched item with the same photo
/// hits the same cache entry.
typedef LocalImageKey = ({String tastingId, String itemId, String? path});

final localImageProvider =
    FutureProvider.family<File?, LocalImageKey>((ref, key) async {
  if (key.path == null || key.path!.isEmpty) return null;
  final store = ref.watch(localMediaStoreProvider);
  final file = await store.fileFor(
    tastingId: key.tastingId,
    itemId: key.itemId,
    remotePath: key.path!,
  );
  return await file.exists() ? file : null;
});

/// A bottle photo read from the device's own folder.
///
/// Nothing here ever touches the network: if the file isn't on disk — because
/// the glass is still blind, or the sync hasn't run — it shows the hatched
/// placeholder instead. [MediaSyncService] is what puts files there.
class BottleThumbnail extends ConsumerWidget {
  const BottleThumbnail({
    super.key,
    required this.item,
    this.width,
    this.height,
    this.radius = 8,
    this.caption,
    this.subtitle,
    this.onNight = false,
    this.onTap,
  });

  final TastingItem item;
  final double? width;
  final double? height;
  final double radius;
  final String? caption;

  /// The second line under [caption] on the empty placeholder — the design
  /// uses it to say a tappable frame can be filled.
  final String? subtitle;

  final bool onNight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref
        .watch(localImageProvider((
          tastingId: item.tastingId,
          itemId: item.id,
          path: item.imagePath,
        )))
        .value;

    if (file == null) {
      return HatchedPlaceholder(
        width: width,
        height: height,
        radius: radius,
        caption: caption,
        subtitle: subtitle,
        onNight: onNight,
        onTap: onTap,
      );
    }

    return GlasTap(
      onTap: onTap,
      radius: radius,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          // A file that vanished under us (cleared storage, say) falls back to
          // the placeholder rather than an error box.
          errorBuilder: (context, _, _) => HatchedPlaceholder(
            width: width,
            height: height,
            radius: radius,
            caption: caption,
            onNight: onNight,
          ),
        ),
      ),
    );
  }
}
