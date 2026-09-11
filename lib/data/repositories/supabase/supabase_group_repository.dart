import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/group.dart';
import '../../models/profile.dart';
import '../group_repository.dart';
import '../tasting_repository.dart';

/// Groups, hosted. **Parked** alongside [SupabaseTastingRepository].
class SupabaseGroupRepository implements GroupRepository {
  SupabaseGroupRepository(this._client);

  final SupabaseClient _client;

  static const _withCounts = '*, group_members(count), tastings(count)';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const TastingException('Ikke logget ind.');
    return id;
  }

  @override
  Future<List<Group>> myGroups() async {
    final rows = await _client
        .from('group_members')
        .select('role, status, groups($_withCounts)')
        .eq('user_id', _userId)
        .order('joined_at');

    return rows.map((row) {
      final group = row['groups'] as Map<String, dynamic>;
      return _hydrate(
        group,
        myRole: MemberRole.fromWire(row['role'] as String?),
        pending: row['status'] == 'pending',
      );
    }).toList();
  }

  @override
  Future<List<Group>> discover({String query = ''}) async {
    var request = _client.from('groups').select(_withCounts);
    if (query.trim().isNotEmpty) {
      final q = query.trim();
      request = request.or('name.ilike.%$q%,description.ilike.%$q%');
    }
    final rows = await request.order('created_at', ascending: false).limit(40);

    final mine = await _myMemberships();
    return rows.map((row) {
      final membership = mine[row['id'] as String];
      return _hydrate(
        row,
        myRole: membership?.role,
        pending: membership?.pending ?? false,
      );
    }).toList();
  }

  @override
  Future<Group> byId(String groupId) async {
    final row = await _client
        .from('groups')
        .select(_withCounts)
        .eq('id', groupId)
        .single();
    final membership = (await _myMemberships())[groupId];
    return _hydrate(
      row,
      myRole: membership?.role,
      pending: membership?.pending ?? false,
    );
  }

  @override
  Future<List<GroupMember>> members(String groupId) async {
    final rows = await _client
        .from('group_members')
        .select('role, status, profiles(id, display_name, avatar_seed, created_at)')
        .eq('group_id', groupId)
        .order('joined_at');
    return rows.map<GroupMember>(GroupMember.fromJson).toList();
  }

  @override
  Future<Group> create({
    required String name,
    String? description,
    List<String> focus = const [],
    GroupAccess access = GroupAccess.approval,
  }) async {
    final row = await _client
        .from('groups')
        .insert({
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
          'focus': focus,
          'access': access.wire,
          'created_by': _userId,
        })
        .select(_withCounts)
        .single();

    // The trigger on groups makes the creator its owner.
    return _hydrate(row, myRole: MemberRole.owner, pending: false);
  }

  @override
  Future<Group> update(
    String groupId, {
    String? name,
    String? description,
    List<String>? focus,
    GroupAccess? access,
  }) async {
    final row = await _client
        .from('groups')
        .update({
          'name': ?name,
          'description': ?description,
          'focus': ?focus,
          'access': ?access?.wire,
        })
        .eq('id', groupId)
        .select(_withCounts)
        .single();
    return _hydrate(row, myRole: MemberRole.owner, pending: false);
  }

  @override
  Future<String> joinByCode(String inviteCode) async {
    try {
      final id = await _client
          .rpc('join_group', params: {'p_invite_code': inviteCode.trim()});
      return id as String;
    } on PostgrestException catch (error) {
      throw TastingException(error.message);
    }
  }

  @override
  Future<bool> requestMembership(String groupId) async {
    final status = await _client
        .rpc('request_group_membership', params: {'p_group_id': groupId});
    return status == 'active';
  }

  @override
  Future<void> approve(String groupId, String userId) async {
    await _client
        .from('group_members')
        .update({'status': 'active'})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  @override
  Future<void> leave(String groupId) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', _userId);
  }

  Future<Map<String, ({MemberRole role, bool pending})>> _myMemberships() async {
    final rows = await _client
        .from('group_members')
        .select('group_id, role, status')
        .eq('user_id', _userId);
    return {
      for (final row in rows)
        row['group_id'] as String: (
          role: MemberRole.fromWire(row['role'] as String?),
          pending: row['status'] == 'pending',
        ),
    };
  }

  static Group _hydrate(
    Map<String, dynamic> row, {
    MemberRole? myRole,
    bool pending = false,
  }) =>
      Group.fromJson(
        row,
        memberCount: _count(row['group_members']),
        tastingCount: _count(row['tastings']),
        myRole: myRole,
        myStatusPending: pending,
      );

  /// PostgREST returns an embedded `count` as `[{"count": n}]`.
  static int _count(Object? embedded) => switch (embedded) {
        final List list when list.isNotEmpty =>
          ((list.first as Map)['count'] as num?)?.toInt() ?? 0,
        final Map map => (map['count'] as num?)?.toInt() ?? 0,
        _ => 0,
      };
}

/// The signed-in person's own record, hosted. **Parked.**
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> me() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;
    final row =
        await _client.from('profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  @override
  Future<Profile> updateName(String displayName) async {
    final id = _client.auth.currentUser!.id;
    final row = await _client
        .from('profiles')
        .update({'display_name': displayName})
        .eq('id', id)
        .select()
        .single();
    return Profile.fromJson(row);
  }
}
