import 'dart:async';
import 'dart:io';

import '../../local/local_media_store.dart';
import '../../models/tasting_item.dart';
import '../media_service.dart';
import 'local_tasting_repository.dart';

/// Images, on the device, shared phone-to-phone.
///
/// There is no upload in local mode: the host's photo simply stays where the
/// picker left it, copied into the app's own folder. What the row records is
/// the file's name, so the other phones know what to ask for.
///
/// Downloads are not fetches either. [syncTasting] asks the host for anything
/// this device is missing and returns; the bytes arrive asynchronously over the
/// tasting socket and land through the repository's `onImage`. That's why this
/// reports progress as "requested" rather than blocking on each file.
class LocalMediaService implements MediaService {
  LocalMediaService(this._store, this._repository);

  final LocalMediaStore _store;
  final LocalTastingRepository _repository;

  @override
  Future<UploadedMedia> upload({
    required String tastingId,
    required String itemId,
    required File source,
  }) async {
    final local = await _store.adopt(
      tastingId: tastingId,
      itemId: itemId,
      source: source,
    );

    return UploadedMedia(
      localFile: local,
      // Locally the "remote path" is just the file's own name — enough to carry
      // the extension, and the same shape the Supabase build stores.
      remotePath: 'image${_extensionOf(local.path)}',
      sha256: await _store.checksumOf(local),
      byteSize: await local.length(),
    );
  }

  @override
  Stream<MediaSyncProgress> syncTasting({
    required String tastingId,
    required List<TastingItem> items,
  }) async* {
    final wanted = <TastingItem>[];
    for (final item in items) {
      if (!item.hasImage || !item.isRevealed) continue;
      final present = await _store.has(
        tastingId: tastingId,
        itemId: item.id,
        remotePath: item.imagePath!,
      );
      if (!present) wanted.add(item);
    }

    yield MediaSyncProgress(completed: 0, total: wanted.length);
    if (wanted.isEmpty) return;

    // The host may be us, in which case the files are already here and there
    // is nothing to ask for.
    if (!_repository.guest.isConnected) {
      yield MediaSyncProgress(completed: wanted.length, total: wanted.length);
      return;
    }

    for (var i = 0; i < wanted.length; i++) {
      _repository.guest.requestImage(wanted[i].id);
      yield MediaSyncProgress(completed: i + 1, total: wanted.length);
    }
  }

  @override
  Future<File?> localFile({
    required String tastingId,
    required TastingItem item,
  }) async {
    if (!item.hasImage) return null;
    final file = await _store.fileFor(
      tastingId: tastingId,
      itemId: item.id,
      remotePath: item.imagePath!,
    );
    return await file.exists() ? file : null;
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot < path.lastIndexOf('/')) return '.jpg';
    return path.substring(dot).toLowerCase();
  }
}
