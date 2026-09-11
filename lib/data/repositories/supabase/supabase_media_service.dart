import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../local/local_media_store.dart';
import '../../models/tasting_item.dart';
import '../media_service.dart';

/// Images, hosted. **Parked** alongside the other Supabase repositories.
///
/// Moves tasting images between the host's device, the bucket, and every
/// participant's device — and nowhere else.
///
/// Upload (host, while building a tasting)
///   local file → adopted into our folder → uploaded to `tastings/<id>/items/`
///   → only the object path + sha256 + size are written to the database row.
///
/// Download (participant, at reveal)
///   the row's object path → one signed GET → bytes verified against sha256
///   → written into this device's own folder. From then on the UI reads disk.
class SupabaseMediaService implements MediaService {
  SupabaseMediaService(this._client, this._store);

  final SupabaseClient _client;
  final LocalMediaStore _store;

  StorageFileApi get _bucket => _client.storage.from(Env.mediaBucket);

  static String remotePathFor({
    required String tastingId,
    required String itemId,
    required String extension,
  }) =>
      'tastings/$tastingId/items/$itemId$extension';

  // --------------------------------------------------------------------- host

  /// Copies the picked file into our own folder, uploads it, and returns the
  /// metadata to persist on the item row.
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

    final bytes = await local.readAsBytes();
    final checksum = await _store.checksumOf(local);
    final remotePath = remotePathFor(
      tastingId: tastingId,
      itemId: itemId,
      extension: _extensionOf(local.path),
    );

    await _bucket.uploadBinary(
      remotePath,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: _mimeOf(local.path),
      ),
    );

    return UploadedMedia(
      localFile: local,
      remotePath: remotePath,
      sha256: checksum,
      byteSize: bytes.length,
    );
  }

  Future<void> removeRemote(String remotePath) async {
    await _bucket.remove([remotePath]);
  }

  // -------------------------------------------------------------- participant

  /// Downloads anything this tasting has revealed that isn't already on disk.
  ///
  /// Safe to call repeatedly: items already present are skipped, so this doubles
  /// as the "resync my device" action in settings.
  @override
  Stream<MediaSyncProgress> syncTasting({
    required String tastingId,
    required List<TastingItem> items,
  }) async* {
    final pending = <TastingItem>[];
    for (final item in items) {
      if (!item.hasImage) continue;
      final present = await _store.has(
        tastingId: tastingId,
        itemId: item.id,
        remotePath: item.imagePath!,
      );
      if (!present) pending.add(item);
    }

    yield MediaSyncProgress(completed: 0, total: pending.length);
    if (pending.isEmpty) return;

    var done = 0;
    for (final item in pending) {
      try {
        await downloadItem(tastingId: tastingId, item: item);
      } on Object catch (error) {
        yield MediaSyncProgress(
          completed: done,
          total: pending.length,
          failedItemId: item.id,
          error: error,
        );
      }
      done++;
      yield MediaSyncProgress(completed: done, total: pending.length);
    }
  }

  Future<File> downloadItem({
    required String tastingId,
    required TastingItem item,
  }) async {
    final remotePath = item.imagePath;
    if (remotePath == null || remotePath.isEmpty) {
      throw StateError('Item ${item.id} has no image to download.');
    }

    final bytes = await _bucket.download(remotePath);

    return _store.write(
      tastingId: tastingId,
      itemId: item.id,
      remotePath: remotePath,
      bytes: bytes,
      expectedSha256: item.imageSha256,
    );
  }

  /// The on-device file for an item, or null when it hasn't been synced yet.
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

  static String _mimeOf(String path) => switch (_extensionOf(path)) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.heic' => 'image/heic',
        _ => 'image/jpeg',
      };
}


