import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../local/local_media_store.dart';
import '../../models/profile.dart';
import '../../models/rating.dart';
import '../../models/tasting.dart';
import '../../models/tasting_config.dart';
import '../../models/tasting_item.dart';
import '../../peer/peer_protocol.dart';
import '../../peer/tasting_guest.dart';
import '../../peer/tasting_host.dart';
import '../../scoring/guess_scorer.dart';
import '../tasting_repository.dart';
import 'local_session.dart';
import 'local_store.dart';

/// Tastings, kept on this device and shared with the phones in the room.
///
/// Whoever created a tasting hosts it: their phone holds the truth, advertises
/// the evening on the local network, and answers the others. Guests keep a
/// mirror written to their own store, so the archive is theirs to keep once
/// everyone has gone home.
///
/// The blind is enforced here, in [_visibleItem], for the same reason the
/// Supabase build enforces it in a view: a guest's device must never be *sent*
/// the answer, because anything sent can be read.
class LocalTastingRepository
    implements TastingRepository, HostDelegate, GuestDelegate {
  LocalTastingRepository(this._store, this._session, this._media) {
    _host = TastingHost(delegate: this);
    _guest = TastingGuest(delegate: this);
  }

  final LocalStore _store;
  final LocalSession _session;
  final LocalMediaStore _media;

  late final TastingHost _host;
  late final TastingGuest _guest;
  final NearbyTastings nearby = NearbyTastings();

  static const _uuid = Uuid();

  /// Fires whenever anything about a tasting changes, locally or from the host.
  final _revisions = StreamController<String>.broadcast();

  TastingHost get host => _host;
  TastingGuest get guest => _guest;

  String get _userId => _session.requireUserId();

  Future<void> dispose() async {
    await _host.dispose();
    await _guest.dispose();
    await nearby.dispose();
    await _revisions.close();
  }

  void _touch(String tastingId) {
    if (!_revisions.isClosed) _revisions.add(tastingId);
  }

  // =========================================================================
  // reading
  // =========================================================================

  @override
  Future<List<Tasting>> myTastings({int limit = 50}) async {
    final mine = await _tastingsIAmIn();
    mine.sort((a, b) {
      final da = a.scheduledFor ?? a.createdAt;
      final db = b.scheduledFor ?? b.createdAt;
      return db.compareTo(da);
    });
    return mine.take(limit).toList();
  }

  @override
  Future<List<Tasting>> finishedTastings({
    String? groupId,
    int limit = 20,
  }) async {
    final all = await _tastingsIAmIn();
    final finished = all
        .where((t) =>
            t.status == TastingStatus.finished &&
            (groupId == null || t.groupId == groupId))
        .toList()
      ..sort((a, b) => (b.finishedAt ?? b.createdAt)
          .compareTo(a.finishedAt ?? a.createdAt));
    return finished.take(limit).toList();
  }

  @override
  Future<Tasting> byId(String tastingId) async {
    final row = await _store.byId(LocalStore.tastings, tastingId);
    if (row == null) {
      throw const TastingException('Smagningen findes ikke på denne enhed.');
    }
    return _hydrate(row);
  }

  @override
  Future<List<TastingItem>> hostItems(String tastingId) async {
    final rows = await _store.where(
      LocalStore.items,
      (row) => row['tasting_id'] == tastingId,
    );
    rows.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    return [
      for (final row in rows) TastingItem.fromJson({...row, 'is_revealed': true}),
    ];
  }

  @override
  Future<List<TastingItem>> items(String tastingId) async {
    final tasting = await byId(tastingId);
    final rows = await _store.where(
      LocalStore.items,
      (row) => row['tasting_id'] == tastingId,
    );
    rows.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));

    final amHost = tasting.hostId == _session.userId;
    return [
      for (final row in rows)
        TastingItem.fromJson(amHost
            ? {...row, 'is_revealed': true}
            : _visibleItem(row, forHost: false)),
    ];
  }

  @override
  Future<List<({Profile profile, bool isHost})>> participants(
      String tastingId) async {
    final rows = await _store.where(
      LocalStore.participants,
      (row) => row['tasting_id'] == tastingId,
    );
    rows.sort((a, b) =>
        (a['joined_at'] as String).compareTo(b['joined_at'] as String));

    final out = <({Profile profile, bool isHost})>[];
    for (final row in rows) {
      final profile = await _store.byId(
        LocalStore.profiles,
        row['user_id'] as String,
      );
      if (profile == null) continue;
      out.add((
        profile: Profile.fromJson(profile),
        isHost: row['is_host'] as bool? ?? false,
      ));
    }
    return out;
  }

  @override
  Future<List<Rating>> ratings(String tastingId) async {
    final tasting = await byId(tastingId);
    final itemIds = {
      for (final row in await _store.where(
        LocalStore.items,
        (row) => row['tasting_id'] == tastingId,
      ))
        row['id'] as String: row,
    };

    final rows = await _store.where(
      LocalStore.ratings,
      (row) => itemIds.containsKey(row['tasting_item_id']),
    );

    // The same visibility rule the Supabase policy applies.
    final showOthers = tasting.config.showOthers;
    return [
      for (final row in rows)
        if (row['user_id'] == _session.userId ||
            _othersVisible(showOthers, itemIds[row['tasting_item_id']]))
          Rating.fromJson(row),
    ];
  }

  static bool _othersVisible(String showOthers, Map<String, dynamic>? item) =>
      switch (showOthers) {
        'Straks' => true,
        'Efter afsløring' => item?['revealed_at'] != null,
        _ => false,
      };

  @override
  Future<Rating?> myRating(String itemId) async {
    final row = await _store.find(
      LocalStore.ratings,
      (row) =>
          row['tasting_item_id'] == itemId && row['user_id'] == _session.userId,
    );
    return row == null ? null : Rating.fromJson(row);
  }

  @override
  Future<List<ArchiveEntry>> myArchive({int limit = 300}) async {
    final mine = await _store.where(
      LocalStore.ratings,
      (row) => row['user_id'] == _session.userId,
    );

    final out = <ArchiveEntry>[];
    for (final row in mine) {
      final item = await _store.byId(
        LocalStore.items,
        row['tasting_item_id'] as String,
      );
      if (item == null || item['revealed_at'] == null) continue;

      final tasting = await _store.byId(
        LocalStore.tastings,
        item['tasting_id'] as String,
      );
      if (tasting == null) continue;

      out.add((
        rating: Rating.fromJson(row),
        item: TastingItem.fromJson({...item, 'is_revealed': true}),
        tasting: _hydrate(tasting),
      ));
    }

    out.sort((a, b) => (b.item.revealedAt ?? b.tasting.createdAt)
        .compareTo(a.item.revealedAt ?? a.tasting.createdAt));
    return out.take(limit).toList();
  }

  // =========================================================================
  // watching — local changes and host pushes both land on the same stream
  // =========================================================================

  @override
  Stream<Tasting> watchTasting(String tastingId) async* {
    yield await byId(tastingId);
    await for (final changed in _revisions.stream) {
      if (changed != tastingId) continue;
      yield await byId(tastingId);
    }
  }

  @override
  Stream<List<TastingItem>> watchItems(String tastingId) async* {
    yield await items(tastingId);
    await for (final changed in _revisions.stream) {
      if (changed != tastingId) continue;
      yield await items(tastingId);
    }
  }

  @override
  Stream<int> watchParticipantCount(String tastingId) async* {
    yield (await participants(tastingId)).length;
    await for (final changed in _revisions.stream) {
      if (changed != tastingId) continue;
      yield (await participants(tastingId)).length;
    }
  }

  @override
  Stream<int> watchRevisions(String tastingId) async* {
    var revision = 0;
    yield revision;
    await for (final changed in _revisions.stream) {
      if (changed == tastingId) yield ++revision;
    }
  }

  // =========================================================================
  // writing
  // =========================================================================

  @override
  Future<Tasting> createTasting({
    required String title,
    String? groupId,
    String? theme,
    String? description,
    String category = 'Vin',
    DateTime? scheduledFor,
    TastingConfig config = const TastingConfig(),
    String? joinCode,
  }) async {
    final id = _uuid.v4();
    final code = (joinCode == null || joinCode.trim().isEmpty)
        ? await _freeJoinCode()
        : joinCode.trim().toUpperCase();

    final row = await _store.upsert(LocalStore.tastings, {
      'id': id,
      'group_id': groupId,
      'host_id': _userId,
      'title': title,
      'theme': theme,
      'description': description,
      'category': category,
      'status': TastingStatus.draft.wire,
      'join_code': code,
      'current_position': 0,
      'config': config.toJson(),
      'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
      'finished_at': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _store.upsert(LocalStore.participants, {
      'id': _uuid.v4(),
      'tasting_id': id,
      'user_id': _userId,
      'is_host': true,
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    });

    _touch(id);
    return _hydrate(row);
  }

  @override
  Future<Tasting> updateTasting(
    String tastingId, {
    String? title,
    String? theme,
    String? description,
    String? category,
    DateTime? scheduledFor,
    TastingConfig? config,
    TastingStatus? status,
  }) async {
    await _requireHost(tastingId);

    final row = await _store.patch(LocalStore.tastings, tastingId, (row) => {
          ...row,
          'title': ?title,
          'theme': ?theme,
          'description': ?description,
          'category': ?category,
          'scheduled_for': ?scheduledFor?.toUtc().toIso8601String(),
          'config': ?config?.toJson(),
          'status': ?status?.wire,
        });

    if (row == null) {
      throw const TastingException('Smagningen findes ikke på denne enhed.');
    }
    _touch(tastingId);
    await _host.broadcastSync();
    return _hydrate(row);
  }

  /// Opens the room, and puts the evening on the air so nearby phones can find
  /// it. This is the moment the host device becomes a server.
  @override
  Future<Tasting> openLobby(String tastingId) async {
    final tasting = await _requireHost(tastingId);
    final updated = await updateTasting(tastingId, status: TastingStatus.lobby);

    final me = await _store.byId(LocalStore.profiles, _userId);
    final glasses = (await hostItems(tastingId)).length;

    await _host.start(
      joinCode: tasting.joinCode,
      title: tasting.title,
      hostName: (me?['display_name'] as String?) ?? 'Vært',
      glasses: glasses,
    );

    return updated;
  }

  /// Finds the host advertising this code and joins their room.
  @override
  Future<String> joinByCode(String code) async {
    final wanted = code.trim().toUpperCase();

    // Already in this room? Just reopen it.
    final known = await _store.find(
      LocalStore.tastings,
      (row) => row['join_code'] == wanted,
    );
    if (known != null && known['host_id'] == _session.userId) {
      return known['id'] as String;
    }

    final host = await nearby.resolve(wanted);
    if (host == null) {
      throw const TastingException(
        'Ingen smagning med den kode i nærheden. '
        'Tjek koden, og at I er på det samme wi-fi.',
      );
    }

    final me = await _store.byId(LocalStore.profiles, _userId);
    if (me == null) {
      throw const TastingException('Din profil mangler.');
    }

    try {
      await _guest.connect(host: host, joinCode: wanted, profile: me);
    } on PeerProtocolException catch (error) {
      throw TastingException(error.message);
    }

    // connect() only returns once the welcome snapshot has been stored.
    final joined = await _store.find(
      LocalStore.tastings,
      (row) => row['join_code'] == wanted,
    );
    if (joined == null) {
      throw const TastingException('Værten sendte ingen smagning.');
    }
    return joined['id'] as String;
  }

  @override
  Future<void> leave(String tastingId) async {
    final tasting = await byId(tastingId);
    if (tasting.hostId == _session.userId) {
      await _host.stop();
    } else {
      await _guest.disconnect();
    }
    await _store.deleteWhere(
      LocalStore.participants,
      (row) =>
          row['tasting_id'] == tastingId && row['user_id'] == _session.userId,
    );
    _touch(tastingId);
  }

  @override
  Future<Tasting> advance(String tastingId, int position) async {
    await _requireHost(tastingId);

    final row = await _store.patch(LocalStore.tastings, tastingId, (row) => {
          ...row,
          'current_position': position,
          if (position > 0) 'status': TastingStatus.live.wire,
        });
    if (row == null) {
      throw const TastingException('Smagningen findes ikke på denne enhed.');
    }

    _touch(tastingId);
    await _host.broadcastSync();
    return _hydrate(row);
  }

  /// Reveals one glass and settles everyone's points for it, in that order —
  /// exactly what `reveal_item()` does in one statement on Postgres.
  @override
  Future<TastingItem> revealItem(String itemId) async {
    final itemRow = await _store.byId(LocalStore.items, itemId);
    if (itemRow == null) {
      throw const TastingException('Glasset findes ikke.');
    }
    final tastingId = itemRow['tasting_id'] as String;
    final tasting = await _requireHost(tastingId);

    final revealed = await _store.patch(LocalStore.items, itemId, (row) => {
          ...row,
          'revealed_at':
              row['revealed_at'] ?? DateTime.now().toUtc().toIso8601String(),
        });
    final item = TastingItem.fromJson({...revealed!, 'is_revealed': true});

    if (tasting.config.guessOn) {
      final forItem = await _store.where(
        LocalStore.ratings,
        (row) => row['tasting_item_id'] == itemId,
      );
      for (final row in forItem) {
        final scored = GuessScorer.score(
          item: item,
          rating: Rating.fromJson(row),
          config: tasting.config,
        );
        await _store.patch(LocalStore.ratings, row['id'] as String, (r) => {
              ...r,
              'points': {
                for (final entry in scored.rows.entries)
                  entry.key.key: {'got': entry.value.got, 'max': entry.value.max},
              },
              'points_total': scored.total,
            });
      }
    }

    _touch(tastingId);
    await _host.broadcastSync();
    return item;
  }

  @override
  Future<Tasting> finish(String tastingId) async {
    await _requireHost(tastingId);

    final row = await _store.patch(LocalStore.tastings, tastingId, (row) => {
          ...row,
          'status': TastingStatus.finished.wire,
          'finished_at': DateTime.now().toUtc().toIso8601String(),
        });

    _touch(tastingId);
    await _host.broadcastSync();
    // Everyone has what they need; take the evening off the air.
    await _host.stop();
    return _hydrate(row!);
  }

  // ------------------------------------------------------------------- items

  @override
  Future<TastingItem> createItem({
    required String tastingId,
    required int position,
  }) async {
    await _requireHost(tastingId);

    final row = await _store.upsert(LocalStore.items, {
      'id': _uuid.v4(),
      'tasting_id': tastingId,
      'position': position,
      'currency': 'DKK',
      'aromas': <String>[],
      'flavours': <String>[],
      'revealed_at': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    _touch(tastingId);
    return TastingItem.fromJson({...row, 'is_revealed': true});
  }

  @override
  Future<TastingItem> saveItem(TastingItem item) async {
    await _requireHost(item.tastingId);

    final existing = await _store.byId(LocalStore.items, item.id) ?? const {};
    final row = await _store.upsert(LocalStore.items, {
      ...existing,
      ...item.toUpsert(),
      // Only revealItem() moves this.
      'revealed_at': existing['revealed_at'],
    });

    _touch(item.tastingId);
    await _host.broadcastSync();
    return TastingItem.fromJson({...row, 'is_revealed': true});
  }

  @override
  Future<void> deleteItem(String itemId) async {
    final row = await _store.byId(LocalStore.items, itemId);
    if (row == null) return;
    await _requireHost(row['tasting_id'] as String);

    await _store.delete(LocalStore.items, itemId);
    await _store.deleteWhere(
      LocalStore.ratings,
      (rating) => rating['tasting_item_id'] == itemId,
    );

    _touch(row['tasting_id'] as String);
    await _host.broadcastSync();
  }

  @override
  Future<void> reorderItems(List<TastingItem> ordered) async {
    if (ordered.isEmpty) return;
    await _requireHost(ordered.first.tastingId);

    for (var i = 0; i < ordered.length; i++) {
      await _store.patch(
        LocalStore.items,
        ordered[i].id,
        (row) => {...row, 'position': i + 1},
      );
    }
    _touch(ordered.first.tastingId);
    await _host.broadcastSync();
  }

  // ----------------------------------------------------------------- ratings

  @override
  Future<Rating> saveRating(Rating rating) async {
    final item = await _store.byId(LocalStore.items, rating.tastingItemId);
    if (item == null) {
      throw const TastingException('Glasset findes ikke.');
    }
    final tastingId = item['tasting_id'] as String;
    final tasting = await byId(tastingId);

    final existing = await _store.find(
      LocalStore.ratings,
      (row) =>
          row['tasting_item_id'] == rating.tastingItemId &&
          row['user_id'] == _userId,
    );

    final payload = {
      'id': existing?['id'] ?? rating.id,
      ...rating.toUpsert(),
      'user_id': _userId,
      // Points are the host's to award, never the writer's.
      'points': existing?['points'],
      'points_total': existing?['points_total'],
    };

    if (tasting.hostId == _userId) {
      final row = await _store.upsert(LocalStore.ratings, payload);
      _touch(tastingId);
      await _host.broadcastSync();
      return Rating.fromJson(row);
    }

    // A guest keeps its own copy so the UI stays responsive offline, and sends
    // it on. The host's next snapshot is what makes it real for everyone else.
    final row = await _store.upsert(LocalStore.ratings, payload);
    _guest.sendRating(payload);
    _touch(tastingId);
    return Rating.fromJson(row);
  }

  // =========================================================================
  // HostDelegate — what guests may ask of us
  // =========================================================================

  @override
  Future<String?> admit({
    required String joinCode,
    required Map<String, dynamic> profile,
  }) async {
    final row = await _store.find(
      LocalStore.tastings,
      (row) => row['join_code'] == joinCode.toUpperCase(),
    );
    if (row == null) return 'Koden findes ikke.';
    if (row['host_id'] != _session.userId) return 'Det er ikke min smagning.';

    final status = TastingStatus.fromWire(row['status'] as String?);
    if (status == TastingStatus.draft) {
      return 'Smagningen er ikke åbnet endnu.';
    }
    if (status == TastingStatus.finished) return 'Smagningen er slut.';

    final userId = profile['id'] as String?;
    if (userId == null) return 'Din profil mangler et id.';

    // Remember who they are, so their name shows in the lobby and their
    // ratings have an owner.
    await _store.upsert(LocalStore.profiles, {
      'id': userId,
      'display_name': profile['display_name'] ?? 'Gæst',
      'avatar_seed': profile['avatar_seed'] ?? userId,
      'created_at':
          profile['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
    });

    final tastingId = row['id'] as String;
    final already = await _store.find(
      LocalStore.participants,
      (p) => p['tasting_id'] == tastingId && p['user_id'] == userId,
    );
    if (already == null) {
      await _store.upsert(LocalStore.participants, {
        'id': _uuid.v4(),
        'tasting_id': tastingId,
        'user_id': userId,
        'is_host': false,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    _touch(tastingId);
    return null;
  }

  @override
  Future<TastingSnapshot> snapshotFor(String userId) async {
    final tasting = await _hostedTasting();
    if (tasting == null) {
      throw const TastingException('Ingen smagning er i gang.');
    }
    final tastingId = tasting['id'] as String;

    final itemRows = await _store.where(
      LocalStore.items,
      (row) => row['tasting_id'] == tastingId,
    );
    itemRows
        .sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));

    final participantRows = await _store.where(
      LocalStore.participants,
      (row) => row['tasting_id'] == tastingId,
    );

    final profileRows = <Map<String, dynamic>>[];
    for (final participant in participantRows) {
      final profile = await _store.byId(
        LocalStore.profiles,
        participant['user_id'] as String,
      );
      if (profile != null) profileRows.add(profile);
    }

    final itemIds = {for (final row in itemRows) row['id'] as String: row};
    final ratingRows = await _store.where(
      LocalStore.ratings,
      (row) => itemIds.containsKey(row['tasting_item_id']),
    );

    final showOthers =
        TastingConfig.parse(tasting['config']).showOthers;

    return TastingSnapshot(
      tasting: tasting,
      // The blind: everything identifying is stripped from glasses this guest
      // hasn't been shown yet.
      items: [
        for (final row in itemRows) _visibleItem(row, forHost: false),
      ],
      participants: participantRows,
      profiles: profileRows,
      ratings: [
        for (final row in ratingRows)
          if (row['user_id'] == userId ||
              _othersVisible(showOthers, itemIds[row['tasting_item_id']]))
            row,
      ],
    );
  }

  @override
  Future<void> applyRating(String userId, Map<String, dynamic> rating) async {
    final itemId = rating['tasting_item_id'] as String?;
    if (itemId == null) return;

    final item = await _store.byId(LocalStore.items, itemId);
    if (item == null) return;

    final tasting = await _hostedTasting();
    if (tasting == null || item['tasting_id'] != tasting['id']) return;

    // Edits stop at the reveal, as the Supabase policy also insists.
    if (item['revealed_at'] != null) return;

    final existing = await _store.find(
      LocalStore.ratings,
      (row) => row['tasting_item_id'] == itemId && row['user_id'] == userId,
    );

    await _store.upsert(LocalStore.ratings, {
      ...rating,
      'id': existing?['id'] ?? rating['id'] ?? _uuid.v4(),
      'user_id': userId,
      'points': existing?['points'],
      'points_total': existing?['points_total'],
    });

    _touch(tasting['id'] as String);
  }

  @override
  Future<void> onLeave(String userId) async {
    final tasting = await _hostedTasting();
    if (tasting == null) return;
    _touch(tasting['id'] as String);
  }

  @override
  Future<({Uint8List bytes, String sha256, String extension})?> imageFor(
    String itemId,
  ) async {
    final item = await _store.byId(LocalStore.items, itemId);
    if (item == null) return null;

    // Only revealed glasses travel. Before that the photo is the answer.
    if (item['revealed_at'] == null) return null;

    final path = item['image_path'] as String?;
    if (path == null || path.isEmpty) return null;

    final file = await _media.fileFor(
      tastingId: item['tasting_id'] as String,
      itemId: itemId,
      remotePath: path,
    );
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    return (
      bytes: bytes,
      sha256: (item['image_sha256'] as String?) ?? '',
      extension: _extensionOf(path),
    );
  }

  // =========================================================================
  // GuestDelegate — what the host tells us
  // =========================================================================

  @override
  Future<void> onSnapshot(TastingSnapshot snapshot) async {
    final tastingId = snapshot.tasting['id'] as String;

    await _store.upsert(LocalStore.tastings, snapshot.tasting);

    for (final profile in snapshot.profiles) {
      await _store.upsert(LocalStore.profiles, profile);
    }

    // The host's picture of the room replaces ours wholesale. Our own rating is
    // the only thing we author, and the host echoes it back in the snapshot.
    await _store.replaceWhere(
      LocalStore.items,
      (row) => row['tasting_id'] == tastingId,
      snapshot.items,
    );
    await _store.replaceWhere(
      LocalStore.participants,
      (row) => row['tasting_id'] == tastingId,
      snapshot.participants,
    );

    final itemIds = {for (final row in snapshot.items) row['id'] as String};
    await _store.replaceWhere(
      LocalStore.ratings,
      (row) => itemIds.contains(row['tasting_item_id']),
      snapshot.ratings,
    );

    _touch(tastingId);

    // Pull the photos of anything newly revealed.
    for (final row in snapshot.items) {
      if (row['revealed_at'] == null) continue;
      final path = row['image_path'] as String?;
      if (path == null || path.isEmpty) continue;

      final present = await _media.has(
        tastingId: tastingId,
        itemId: row['id'] as String,
        remotePath: path,
      );
      if (!present) _guest.requestImage(row['id'] as String);
    }
  }

  @override
  Future<void> onImage({
    required String itemId,
    required String sha256,
    required String extension,
    required Uint8List bytes,
  }) async {
    final item = await _store.byId(LocalStore.items, itemId);
    if (item == null) return;

    await _media.write(
      tastingId: item['tasting_id'] as String,
      itemId: itemId,
      remotePath: 'image$extension',
      bytes: bytes,
      expectedSha256: sha256.isEmpty ? null : sha256,
    );
    _touch(item['tasting_id'] as String);
  }

  @override
  void onDisconnected(String? reason) {
    final code = _guest.joinCode;
    if (code == null) return;
    // Nothing to undo: the mirror on disk is still good, it just stops moving.
  }

  // =========================================================================
  // internals
  // =========================================================================

  /// The blind, in one place.
  ///
  /// Mirrors `tasting_items_visible`: until a glass is revealed, everything
  /// that would identify it comes back null — and host notes never travel at
  /// all, revealed or not.
  static Map<String, dynamic> _visibleItem(
    Map<String, dynamic> row, {
    required bool forHost,
  }) {
    final revealed = row['revealed_at'] != null;
    if (forHost) return {...row, 'is_revealed': true};

    if (!revealed) {
      return {
        'id': row['id'],
        'tasting_id': row['tasting_id'],
        'position': row['position'],
        'is_revealed': false,
        'revealed_at': null,
        'created_at': row['created_at'],
      };
    }

    return {
      ...row,
      'is_revealed': true,
      'host_notes': null,
    };
  }

  Future<List<Tasting>> _tastingsIAmIn() async {
    final userId = _session.userId;
    if (userId == null) return [];

    final mine = await _store.where(
      LocalStore.participants,
      (row) => row['user_id'] == userId,
    );
    final ids = {for (final row in mine) row['tasting_id'] as String};

    final rows = await _store.where(
      LocalStore.tastings,
      (row) => ids.contains(row['id']) || row['host_id'] == userId,
    );
    return [for (final row in rows) _hydrate(row)];
  }

  /// Tastings carry their group's and host's names for display; locally those
  /// live in other collections, so they're stitched in on read.
  Tasting _hydrate(Map<String, dynamic> row) {
    final hostId = row['host_id'] as String?;
    final groupId = row['group_id'] as String?;
    return Tasting.fromJson({
      ...row,
      if (hostId != null && _nameCache.containsKey(hostId))
        'profiles': {'display_name': _nameCache[hostId]},
      if (groupId != null && _groupCache.containsKey(groupId))
        'groups': {'name': _groupCache[groupId]},
    });
  }

  final _nameCache = <String, String>{};
  final _groupCache = <String, String>{};

  /// Warms the display-name caches [_hydrate] reads. Called by the providers
  /// before a screen loads, and cheap enough to repeat.
  Future<void> warmCaches() async {
    for (final row in await _store.all(LocalStore.profiles)) {
      _nameCache[row['id'] as String] = row['display_name'] as String? ?? '';
    }
    for (final row in await _store.all(LocalStore.groups)) {
      _groupCache[row['id'] as String] = row['name'] as String? ?? '';
    }
  }

  Future<Tasting> _requireHost(String tastingId) async {
    final tasting = await byId(tastingId);
    if (tasting.hostId != _session.userId) {
      throw const TastingException('Kun værten kan ændre smagningen.');
    }
    return tasting;
  }

  Future<Map<String, dynamic>?> _hostedTasting() async {
    final userId = _session.userId;
    if (userId == null) return null;

    final rows = await _store.where(
      LocalStore.tastings,
      (row) =>
          row['host_id'] == userId &&
          row['status'] != TastingStatus.draft.wire &&
          row['status'] != TastingStatus.finished.wire,
    );
    if (rows.isEmpty) return null;

    rows.sort((a, b) =>
        (b['created_at'] as String).compareTo(a['created_at'] as String));
    return rows.first;
  }

  /// Six characters, and not one already in use on this device.
  Future<String> _freeJoinCode() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final existing = {
      for (final row in await _store.all(LocalStore.tastings))
        row['join_code'] as String,
    };

    for (var attempt = 0; attempt < 50; attempt++) {
      final seed = _uuid.v4().replaceAll('-', '').toUpperCase();
      final code = [
        for (var i = 0; i < 6; i++)
          alphabet[seed.codeUnitAt(i) % alphabet.length],
      ].join();
      if (!existing.contains(code)) return code;
    }
    throw const TastingException('Kunne ikke lave en ledig kode.');
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot < path.lastIndexOf('/')) return '.jpg';
    return path.substring(dot).toLowerCase();
  }
}
