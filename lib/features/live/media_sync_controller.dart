import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/repositories/media_service.dart';
import 'bottle_thumbnail.dart';

/// Pulls every revealed photo in a tasting onto this device.
///
/// Watching this provider is what turns a reveal into a file in the user's own
/// folder: it downloads each image once, verifies it against the checksum on
/// the row, and invalidates the thumbnail so the UI swaps from the hatched
/// placeholder to the real photo.
///
/// Safe to watch from several screens — images already on disk are skipped, so
/// re-entering a screen costs one cheap existence check per glass.
class MediaSyncController extends AsyncNotifier<MediaSyncProgress> {
  MediaSyncController(this.tastingId);

  final String tastingId;

  @override
  Future<MediaSyncProgress> build() async {
    final items = await ref.watch(itemsProvider(tastingId).future);
    final revealed = items.where((i) => i.isRevealed && i.hasImage).toList();

    if (revealed.isEmpty) {
      return const MediaSyncProgress(completed: 0, total: 0);
    }

    final service = ref.watch(mediaServiceProvider);
    var last = MediaSyncProgress(completed: 0, total: revealed.length);

    await for (final progress
        in service.syncTasting(tastingId: tastingId, items: revealed)) {
      last = progress;
      if (!ref.mounted) break;
      state = AsyncData(progress);
    }

    // Point every thumbnail at the files that just landed.
    for (final item in revealed) {
      ref.invalidate(localImageProvider((
        tastingId: tastingId,
        itemId: item.id,
        path: item.imagePath,
      )));
    }

    return last;
  }

  /// "Hent billeder igen" in settings, and the retry after a failed download.
  Future<void> resync() async {
    ref.invalidateSelf();
    await future;
  }
}

final mediaSyncProvider = AsyncNotifierProvider.family<MediaSyncController,
    MediaSyncProgress, String>(MediaSyncController.new);
