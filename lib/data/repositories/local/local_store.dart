import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The device's own database.
///
/// A tasting club generates very little data — a few dozen evenings, a few
/// thousand ratings over years — so this is a set of JSON documents held in
/// memory and written back atomically, rather than an embedded SQL engine. It
/// keeps the whole store inspectable, makes the peer protocol a straight
/// pass-through of the same maps, and means there is no schema migration to run
/// on a phone.
///
/// Everything lives beside the images, under the folder the user can see:
///
///   `<app documents>/I Glasset/data/<collection>.json`
class LocalStore {
  LocalStore({Directory? root}) : _rootOverride = root;

  static const _folderName = 'I Glasset';

  final Directory? _rootOverride;
  Directory? _dir;

  final _collections = <String, List<Map<String, dynamic>>>{};
  final _loaded = <String>{};

  /// Serialises writes so two near-simultaneous saves can't interleave.
  Future<void> _pending = Future.value();

  /// Emits the name of a collection whenever it changes, so repositories can
  /// rebuild their streams.
  final _changes = StreamController<String>.broadcast();

  Stream<String> get changes => _changes.stream;

  Future<Directory> _directory() async {
    if (_dir != null) return _dir!;
    final base = _rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_folderName/data');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  File _fileFor(Directory dir, String collection) =>
      File('${dir.path}/$collection.json');

  Future<List<Map<String, dynamic>>> _load(String collection) async {
    if (_loaded.contains(collection)) return _collections[collection]!;

    final file = _fileFor(await _directory(), collection);
    var rows = <Map<String, dynamic>>[];

    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          rows = decoded.cast<Map<String, dynamic>>();
        }
      } on Object {
        // A truncated or hand-edited file shouldn't brick the app. Keep the
        // bad copy for forensics and carry on with an empty collection.
        await file.rename('${file.path}.corrupt');
      }
    }

    _collections[collection] = rows;
    _loaded.add(collection);
    return rows;
  }

  Future<void> _persist(String collection) {
    return _pending = _pending.then((_) async {
      final file = _fileFor(await _directory(), collection);
      final temp = File('${file.path}.part');
      await temp.writeAsString(
        jsonEncode(_collections[collection] ?? const []),
        flush: true,
      );
      await temp.rename(file.path);
      if (!_changes.isClosed) _changes.add(collection);
    });
  }

  // ---------------------------------------------------------------- reading

  Future<List<Map<String, dynamic>>> all(String collection) async {
    final rows = await _load(collection);
    // Hand out copies: callers routinely mutate what they read.
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  Future<List<Map<String, dynamic>>> where(
    String collection,
    bool Function(Map<String, dynamic> row) test,
  ) async {
    final rows = await _load(collection);
    return [
      for (final row in rows)
        if (test(row)) Map<String, dynamic>.from(row),
    ];
  }

  Future<Map<String, dynamic>?> find(
    String collection,
    bool Function(Map<String, dynamic> row) test,
  ) async {
    final rows = await _load(collection);
    for (final row in rows) {
      if (test(row)) return Map<String, dynamic>.from(row);
    }
    return null;
  }

  Future<Map<String, dynamic>?> byId(String collection, String id) =>
      find(collection, (row) => row['id'] == id);

  // ---------------------------------------------------------------- writing

  /// Inserts or replaces a row, matched on `id`.
  Future<Map<String, dynamic>> upsert(
    String collection,
    Map<String, dynamic> row,
  ) async {
    final rows = await _load(collection);
    final index = rows.indexWhere((existing) => existing['id'] == row['id']);
    final stored = Map<String, dynamic>.from(row);

    if (index == -1) {
      rows.add(stored);
    } else {
      rows[index] = stored;
    }
    await _persist(collection);
    return Map<String, dynamic>.from(stored);
  }

  /// Replaces a whole collection — used when a guest receives a fresh snapshot
  /// of a tasting from the host.
  Future<void> replaceWhere(
    String collection,
    bool Function(Map<String, dynamic> row) test,
    List<Map<String, dynamic>> replacements,
  ) async {
    final rows = await _load(collection);
    rows.removeWhere(test);
    rows.addAll([for (final row in replacements) Map<String, dynamic>.from(row)]);
    await _persist(collection);
  }

  Future<void> delete(String collection, String id) async {
    final rows = await _load(collection);
    rows.removeWhere((row) => row['id'] == id);
    await _persist(collection);
  }

  Future<void> deleteWhere(
    String collection,
    bool Function(Map<String, dynamic> row) test,
  ) async {
    final rows = await _load(collection);
    rows.removeWhere(test);
    await _persist(collection);
  }

  /// Applies an edit to one row in place.
  Future<Map<String, dynamic>?> patch(
    String collection,
    String id,
    Map<String, dynamic> Function(Map<String, dynamic> row) edit,
  ) async {
    final rows = await _load(collection);
    final index = rows.indexWhere((row) => row['id'] == id);
    if (index == -1) return null;

    rows[index] = edit(Map<String, dynamic>.from(rows[index]));
    await _persist(collection);
    return Map<String, dynamic>.from(rows[index]);
  }

  /// Waits for every queued write to reach disk. Tests and shutdown use this.
  Future<void> flush() => _pending;

  Future<void> dispose() async {
    await flush();
    await _changes.close();
  }

  // ------------------------------------------------------------- collections

  static const profiles = 'profiles';
  static const groups = 'groups';
  static const groupMembers = 'group_members';
  static const tastings = 'tastings';
  static const items = 'tasting_items';
  static const participants = 'participants';
  static const ratings = 'ratings';

  /// Where the signed-in device profile's id is remembered.
  static const session = 'session';
}
