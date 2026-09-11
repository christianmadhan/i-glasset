import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Every tasting image the user is entitled to keep lives here, on their own
/// device, under a folder they own.
///
/// The database never holds image bytes. Supabase Storage holds them only long
/// enough to hand one copy to each participant; from the moment a tasting is
/// revealed, this store is the source of truth the UI renders from.
///
/// Layout:
///   `<app documents>/I Glasset/tastings/<tastingId>/items/<itemId>.<ext>`
class LocalMediaStore {
  LocalMediaStore({Directory? root}) : _rootOverride = root;

  static const _folderName = 'I Glasset';

  final Directory? _rootOverride;
  Directory? _root;

  /// The user-visible folder holding everything this app has downloaded.
  Future<Directory> root() async {
    if (_root != null) return _root!;
    final base = _rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _root = dir;
  }

  Future<Directory> tastingDir(String tastingId) async {
    final dir = Directory('${(await root()).path}/tastings/$tastingId/items');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Where an item's image would live locally, given the remote storage path
  /// (used only to carry the file extension across).
  Future<File> fileFor({
    required String tastingId,
    required String itemId,
    required String remotePath,
  }) async {
    final dir = await tastingDir(tastingId);
    return File('${dir.path}/$itemId${_extensionOf(remotePath)}');
  }

  Future<bool> has({
    required String tastingId,
    required String itemId,
    required String remotePath,
  }) async {
    final file = await fileFor(
      tastingId: tastingId,
      itemId: itemId,
      remotePath: remotePath,
    );
    return file.exists();
  }

  /// Writes bytes to the device, verifying the checksum the row advertised so a
  /// truncated download can never masquerade as a cached image.
  Future<File> write({
    required String tastingId,
    required String itemId,
    required String remotePath,
    required List<int> bytes,
    String? expectedSha256,
  }) async {
    if (expectedSha256 != null) {
      final actual = sha256.convert(bytes).toString();
      if (actual != expectedSha256) {
        throw MediaChecksumMismatch(
          itemId: itemId,
          expected: expectedSha256,
          actual: actual,
        );
      }
    }

    final file = await fileFor(
      tastingId: tastingId,
      itemId: itemId,
      remotePath: remotePath,
    );

    // Write to a temp sibling then rename, so an interrupted download never
    // leaves a half-written file that `has()` would report as present.
    final temp = File('${file.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
    return file;
  }

  /// Copies a file the host picked from their camera roll into our own folder,
  /// so the host's gallery stays untouched and we own the lifetime of the copy.
  Future<File> adopt({
    required String tastingId,
    required String itemId,
    required File source,
  }) async {
    final file = await fileFor(
      tastingId: tastingId,
      itemId: itemId,
      remotePath: source.path,
    );
    return source.copy(file.path);
  }

  Future<String> checksumOf(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<void> deleteTasting(String tastingId) async {
    final dir = Directory('${(await root()).path}/tastings/$tastingId');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Total bytes held on device — shown in Settings so the user can see, and
  /// reclaim, what the app is keeping for them.
  Future<int> usedBytes() async {
    final dir = await root();
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static String _extensionOf(String path) {
    final clean = path.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot == -1 || dot < clean.lastIndexOf('/')) return '.jpg';
    final ext = clean.substring(dot).toLowerCase();
    return ext.length <= 5 ? ext : '.jpg';
  }
}

class MediaChecksumMismatch implements Exception {
  const MediaChecksumMismatch({
    required this.itemId,
    required this.expected,
    required this.actual,
  });

  final String itemId;
  final String expected;
  final String actual;

  @override
  String toString() =>
      'Downloaded image for item $itemId did not match its checksum '
      '(expected $expected, got $actual).';
}
