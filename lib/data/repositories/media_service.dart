import 'dart:io';

import '../models/tasting_item.dart';

/// Moves tasting images between the host's device and everyone else's — and
/// nowhere else.
///
/// Whatever the backend, the contract is the same: **the device's own folder is
/// the store**. The network is only ever a courier, and only for glasses that
/// have already been revealed.
abstract interface class MediaService {
  /// Takes a picked photo into the app's own folder and makes it available to
  /// participants. Returns what to persist on the item row.
  Future<UploadedMedia> upload({
    required String tastingId,
    required String itemId,
    required File source,
  });

  /// Pulls every revealed image in a tasting onto this device. Idempotent:
  /// anything already on disk is skipped.
  Stream<MediaSyncProgress> syncTasting({
    required String tastingId,
    required List<TastingItem> items,
  });

  /// The on-device file for an item, or null when it hasn't been synced yet.
  Future<File?> localFile({
    required String tastingId,
    required TastingItem item,
  });
}

class UploadedMedia {
  const UploadedMedia({
    required this.localFile,
    required this.remotePath,
    required this.sha256,
    required this.byteSize,
  });

  final File localFile;

  /// Where the courier can find it. A storage object path with Supabase; with
  /// peer sync, simply the file's name within the tasting.
  final String remotePath;
  final String sha256;
  final int byteSize;
}

class MediaSyncProgress {
  const MediaSyncProgress({
    required this.completed,
    required this.total,
    this.failedItemId,
    this.error,
  });

  final int completed;
  final int total;
  final String? failedItemId;
  final Object? error;

  bool get isDone => completed >= total;
  double get fraction => total == 0 ? 1 : completed / total;
}
