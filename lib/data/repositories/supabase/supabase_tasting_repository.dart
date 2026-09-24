import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/profile.dart';
import '../../models/rating.dart';
import '../../models/tasting.dart';
import '../../models/tasting_config.dart';
import '../../models/tasting_item.dart';
import '../tasting_repository.dart';

/// Tastings, hosted.
///
/// **Parked.** The app ships against [LocalTastingRepository] today; this is
/// kept working and ready so switching `Env.backend` to `supabase` is the whole
/// migration. The SQL it depends on lives in `supabase/migrations/`.
///
/// Where the local build enforces the blind and the scoring on the host phone,
/// this leaves both to Postgres: reads go through `tasting_items_visible`, and
/// `reveal_item()` settles the points.
class SupabaseTastingRepository implements TastingRepository {
  SupabaseTastingRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  static const _withNames =
      '*, groups(name), profiles!tastings_host_id_fkey(display_name)';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const TastingException('Ikke logget ind.');
    return id;
  }

  // ------------------------------------------------------------------ reading

  @override
  Future<List<Tasting>> myTastings({int limit = 50}) async {
    final rows = await _client
        .from('tastings')
        .select(_withNames)
        .order('scheduled_for', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map<Tasting>(Tasting.fromJson).toList();
  }

  @override
  Future<List<Tasting>> finishedTastings({
    String? groupId,
    int limit = 20,
  }) async {
    var query = _client
        .from('tastings')
        .select(_withNames)
        .eq('status', TastingStatus.finished.wire);
    if (groupId != null) query = query.eq('group_id', groupId);

    final rows = await query.order('finished_at', ascending: false).limit(limit);
    return rows.map<Tasting>(Tasting.fromJson).toList();
  }

  @override
  Future<Tasting> byId(String tastingId) async {
    final row = await _client
        .from('tastings')
        .select(_withNames)
        .eq('id', tastingId)
        .single();
    return Tasting.fromJson(row);
  }

  @override
  Future<List<TastingItem>> hostItems(String tastingId) async {
    final rows = await _client
        .from('tasting_items')
        .select()
        .eq('tasting_id', tastingId)
        .order('position');
    return rows
        .map<TastingItem>((r) => TastingItem.fromJson({...r, 'is_revealed': true}))
        .toList();
  }

  @override
  Future<List<TastingItem>> items(String tastingId) async {
    final rows = await _client
        .from('tasting_items_visible')
        .select()
        .eq('tasting_id', tastingId)
        .order('position');
    return rows.map<TastingItem>(TastingItem.fromJson).toList();
  }

  @override
  Future<List<({Profile profile, bool isHost})>> participants(
      String tastingId) async {
    final rows = await _client
        .from('participants')
        .select('is_host, profiles(id, display_name, avatar_seed, created_at)')
        .eq('tasting_id', tastingId)
        .order('joined_at');
    return rows
        .map((r) => (
              profile: Profile.fromJson(r['profiles'] as Map<String, dynamic>),
              isHost: r['is_host'] as bool? ?? false,
            ))
        .toList();
  }

  @override
  Future<List<Rating>> ratings(String tastingId) async {
    final rows = await _client
        .from('ratings')
        .select('*, tasting_items!inner(tasting_id)')
        .eq('tasting_items.tasting_id', tastingId);
    return rows.map<Rating>(Rating.fromJson).toList();
  }

  @override
  Future<Rating?> myRating(String itemId) async {
    final row = await _client
        .from('ratings')
        .select()
        .eq('tasting_item_id', itemId)
        .eq('user_id', _userId)
        .maybeSingle();
    return row == null ? null : Rating.fromJson(row);
  }

  @override
  Future<List<ArchiveEntry>> myArchive({int limit = 300}) async {
    final rows = await _client
        .from('ratings')
        .select('*, tasting_items!inner(*, tastings!inner(*))')
        .eq('user_id', _userId)
        .not('tasting_items.revealed_at', 'is', null)
        .limit(limit);

    return rows.map<ArchiveEntry>((row) {
      final itemJson = row['tasting_items'] as Map<String, dynamic>;
      final tastingJson = itemJson['tastings'] as Map<String, dynamic>;
      return (
        rating: Rating.fromJson(row),
        item: TastingItem.fromJson({...itemJson, 'is_revealed': true}),
        tasting: Tasting.fromJson(tastingJson),
      );
    }).toList();
  }

  // ----------------------------------------------------------------- watching

  @override
  Stream<Tasting> watchTasting(String tastingId) => _client
      .from('tastings')
      .stream(primaryKey: ['id'])
      .eq('id', tastingId)
      .map((rows) => Tasting.fromJson(rows.first));

  @override
  Stream<List<TastingItem>> watchItems(String tastingId) => _client
      .from('tasting_items')
      .stream(primaryKey: ['id'])
      .eq('tasting_id', tastingId)
      .map((rows) {
        final items = rows.map<TastingItem>(TastingItem.fromJson).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        return items;
      });

  @override
  Stream<int> watchParticipantCount(String tastingId) => _client
      .from('participants')
      .stream(primaryKey: ['id'])
      .eq('tasting_id', tastingId)
      .map((rows) => rows.length);

  /// One signal out of the several subscriptions that make up an evening.
  @override
  Stream<int> watchRevisions(String tastingId) {
    final controller = StreamController<int>.broadcast();
    var revision = 0;

    final subscriptions = <StreamSubscription<Object?>>[
      watchTasting(tastingId).listen((_) => controller.add(++revision)),
      watchItems(tastingId).listen((_) => controller.add(++revision)),
      watchParticipantCount(tastingId).listen((_) => controller.add(++revision)),
      _client
          .from('ratings')
          .stream(primaryKey: ['id']).listen((_) => controller.add(++revision)),
    ];

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
    return controller.stream;
  }

  // ------------------------------------------------------------------ writing

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
    final row = await _client
        .from('tastings')
        .insert({
          'host_id': _userId,
          'group_id': ?groupId,
          'title': title,
          if (theme != null && theme.isNotEmpty) 'theme': theme,
          if (description != null && description.isNotEmpty)
            'description': description,
          'category': category,
          'status': TastingStatus.draft.wire,
          if (scheduledFor != null)
            'scheduled_for': scheduledFor.toUtc().toIso8601String(),
          'config': config.toJson(),
          if (joinCode != null && joinCode.isNotEmpty)
            'join_code': joinCode.toUpperCase(),
        })
        .select(_withNames)
        .single();

    return Tasting.fromJson(row);
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
    final row = await _client
        .from('tastings')
        .update({
          'title': ?title,
          'theme': ?theme,
          'description': ?description,
          'category': ?category,
          'scheduled_for': ?scheduledFor?.toUtc().toIso8601String(),
          'config': ?config?.toJson(),
          'status': ?status?.wire,
        })
        .eq('id', tastingId)
        .select(_withNames)
        .single();
    return Tasting.fromJson(row);
  }

  @override
  Future<Tasting> openLobby(String tastingId) async {
    // Same rule as the device build: coming back to a live evening reopens it
    // where it stands rather than sending the room back to the lobby.
    final current = await byId(tastingId);
    final tasting = current.status == TastingStatus.live
        ? current
        : await updateTasting(tastingId, status: TastingStatus.lobby);
    await joinByCode(tasting.joinCode);
    return tasting;
  }

  @override
  Future<String> joinByCode(String code) async {
    try {
      final id = await _client.rpc(
        'join_tasting',
        params: {'p_join_code': code.trim().toUpperCase()},
      );
      return id as String;
    } on PostgrestException catch (error) {
      throw TastingException(error.message);
    }
  }

  @override
  Future<void> leave(String tastingId) async {
    await _client
        .from('participants')
        .delete()
        .eq('tasting_id', tastingId)
        .eq('user_id', _userId);
  }

  @override
  Future<Tasting> advance(String tastingId, int position) async {
    final row = await _client.rpc(
      'advance_tasting',
      params: {'p_tasting_id': tastingId, 'p_position': position},
    );
    return Tasting.fromJson(_single(row));
  }

  @override
  Future<TastingItem> revealItem(String itemId) async {
    final row = await _client.rpc('reveal_item', params: {'p_item_id': itemId});
    return TastingItem.fromJson({..._single(row), 'is_revealed': true});
  }

  @override
  Future<void> removeParticipant(String tastingId, String userId) async {
    throw const TastingException(
      'At fjerne deltagere er ikke understøttet mod den hostede backend endnu.',
    );
  }

  @override
  Future<Tasting> finish(String tastingId) async {
    final row =
        await _client.rpc('finish_tasting', params: {'p_tasting_id': tastingId});
    return Tasting.fromJson(_single(row));
  }

  // -------------------------------------------------------------------- items

  @override
  Future<TastingItem> createItem({
    required String tastingId,
    required int position,
  }) async {
    final row = await _client
        .from('tasting_items')
        .insert({
          'id': _uuid.v4(),
          'tasting_id': tastingId,
          'position': position,
        })
        .select()
        .single();
    return TastingItem.fromJson({...row, 'is_revealed': true});
  }

  @override
  Future<TastingItem> saveItem(TastingItem item) async {
    final row = await _client
        .from('tasting_items')
        .upsert(item.toUpsert())
        .select()
        .single();
    return TastingItem.fromJson({...row, 'is_revealed': true});
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _client.from('tasting_items').delete().eq('id', itemId);
  }

  /// Positions are unique per tasting, so the rows move through a negative
  /// no-man's-land first to avoid colliding with their neighbours.
  @override
  Future<void> reorderItems(List<TastingItem> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      await _client
          .from('tasting_items')
          .update({'position': -(i + 1)}).eq('id', ordered[i].id);
    }
    for (var i = 0; i < ordered.length; i++) {
      await _client
          .from('tasting_items')
          .update({'position': i + 1}).eq('id', ordered[i].id);
    }
  }

  // ------------------------------------------------------------------ ratings

  @override
  Future<Rating> saveRating(Rating rating) async {
    final row = await _client
        .from('ratings')
        .upsert(rating.toUpsert(), onConflict: 'tasting_item_id,user_id')
        .select()
        .single();
    return Rating.fromJson(row);
  }

  static Map<String, dynamic> _single(dynamic row) => row is List
      ? row.first as Map<String, dynamic>
      : row as Map<String, dynamic>;
}
