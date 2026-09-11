import 'package:uuid/uuid.dart';

import '../../models/group.dart';
import '../../models/profile.dart';
import '../group_repository.dart';
import '../tasting_repository.dart';
import 'local_session.dart';
import 'local_store.dart';

/// Groups on the device.
///
/// A club is local bookkeeping: it names the evenings, keeps the standings and
/// remembers who was there. Membership arrives the way everything else does —
/// through the snapshot the host sends when you join a tasting — so a group
/// fills in as you taste with people rather than needing a server to hand out
/// invitations.
class LocalGroupRepository implements GroupRepository {
  LocalGroupRepository(this._store, this._session);

  final LocalStore _store;
  final LocalSession _session;

  static const _uuid = Uuid();

  String get _userId => _session.requireUserId();

  @override
  Future<List<Group>> myGroups() async {
    final memberships = await _store.where(
      LocalStore.groupMembers,
      (row) => row['user_id'] == _session.userId,
    );

    final out = <Group>[];
    for (final membership in memberships) {
      final row = await _store.byId(
        LocalStore.groups,
        membership['group_id'] as String,
      );
      if (row == null) continue;
      out.add(await _hydrate(row, membership));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// Without a server there is no directory to search, so this offers what the
  /// device already knows: the groups you're in, filtered by the query. The
  /// Supabase build searches every open club instead.
  @override
  Future<List<Group>> discover({String query = ''}) async {
    final mine = await myGroups();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return mine;

    return mine
        .where((group) =>
            group.name.toLowerCase().contains(q) ||
            (group.description ?? '').toLowerCase().contains(q) ||
            group.focus.any((f) => f.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Future<Group> byId(String groupId) async {
    final row = await _store.byId(LocalStore.groups, groupId);
    if (row == null) {
      throw const TastingException('Gruppen findes ikke på denne enhed.');
    }
    final membership = await _store.find(
      LocalStore.groupMembers,
      (m) => m['group_id'] == groupId && m['user_id'] == _session.userId,
    );
    return _hydrate(row, membership);
  }

  @override
  Future<List<GroupMember>> members(String groupId) async {
    final rows = await _store.where(
      LocalStore.groupMembers,
      (row) => row['group_id'] == groupId,
    );
    rows.sort((a, b) =>
        (a['joined_at'] as String).compareTo(b['joined_at'] as String));

    final out = <GroupMember>[];
    for (final row in rows) {
      final profile = await _store.byId(
        LocalStore.profiles,
        row['user_id'] as String,
      );
      if (profile == null) continue;
      out.add(GroupMember(
        profile: Profile.fromJson(profile),
        role: MemberRole.fromWire(row['role'] as String?),
        pending: row['status'] == 'pending',
      ));
    }
    return out;
  }

  @override
  Future<Group> create({
    required String name,
    String? description,
    List<String> focus = const [],
    GroupAccess access = GroupAccess.approval,
  }) async {
    final id = _uuid.v4();
    final row = await _store.upsert(LocalStore.groups, {
      'id': id,
      'name': name,
      'description': description,
      'focus': focus,
      'access': access.wire,
      'invite_code': await _freeInviteCode(),
      'created_by': _userId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _store.upsert(LocalStore.groupMembers, {
      'id': '$id:$_userId',
      'group_id': id,
      'user_id': _userId,
      'role': MemberRole.owner.wire,
      'status': 'active',
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    });

    return _hydrate(row, {'role': MemberRole.owner.wire, 'status': 'active'});
  }

  @override
  Future<Group> update(
    String groupId, {
    String? name,
    String? description,
    List<String>? focus,
    GroupAccess? access,
  }) async {
    final row = await _store.patch(LocalStore.groups, groupId, (row) => {
          ...row,
          'name': ?name,
          'description': ?description,
          'focus': ?focus,
          'access': ?access?.wire,
        });
    if (row == null) {
      throw const TastingException('Gruppen findes ikke på denne enhed.');
    }
    return byId(groupId);
  }

  /// With no server to ask, a code only opens a group this device already knows
  /// — one you created, or one that arrived with a tasting you joined.
  @override
  Future<String> joinByCode(String inviteCode) async {
    final row = await _store.find(
      LocalStore.groups,
      (row) =>
          (row['invite_code'] as String?)?.toUpperCase() ==
          inviteCode.trim().toUpperCase(),
    );
    if (row == null) {
      throw const TastingException(
        'Gruppekoden findes ikke her. Deltag først i en smagning med gruppen.',
      );
    }
    await requestMembership(row['id'] as String);
    return row['id'] as String;
  }

  @override
  Future<bool> requestMembership(String groupId) async {
    await _store.upsert(LocalStore.groupMembers, {
      'id': '$groupId:$_userId',
      'group_id': groupId,
      'user_id': _userId,
      'role': MemberRole.member.wire,
      'status': 'active',
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    });
    return true;
  }

  @override
  Future<void> approve(String groupId, String userId) async {
    await _store.patch(
      LocalStore.groupMembers,
      '$groupId:$userId',
      (row) => {...row, 'status': 'active'},
    );
  }

  @override
  Future<void> leave(String groupId) =>
      _store.delete(LocalStore.groupMembers, '$groupId:$_userId');

  Future<Group> _hydrate(
    Map<String, dynamic> row,
    Map<String, dynamic>? membership,
  ) async {
    final groupId = row['id'] as String;
    final memberCount = (await _store.where(
      LocalStore.groupMembers,
      (m) => m['group_id'] == groupId && m['status'] != 'pending',
    ))
        .length;
    final tastingCount = (await _store.where(
      LocalStore.tastings,
      (t) => t['group_id'] == groupId && t['status'] == 'finished',
    ))
        .length;

    return Group.fromJson(
      row,
      memberCount: memberCount,
      tastingCount: tastingCount,
      myRole: membership == null
          ? null
          : MemberRole.fromWire(membership['role'] as String?),
      myStatusPending: membership?['status'] == 'pending',
    );
  }

  Future<String> _freeInviteCode() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final existing = {
      for (final row in await _store.all(LocalStore.groups))
        (row['invite_code'] as String?)?.toUpperCase(),
    };

    for (var attempt = 0; attempt < 50; attempt++) {
      final seed = _uuid.v4().replaceAll('-', '').toUpperCase();
      final code = 'GRP-${[
        for (var i = 0; i < 4; i++)
          alphabet[seed.codeUnitAt(i) % alphabet.length],
      ].join()}';
      if (!existing.contains(code)) return code;
    }
    throw const TastingException('Kunne ikke lave en ledig gruppekode.');
  }
}

/// The signed-in person's own record, on the device.
class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._store, this._session);

  final LocalStore _store;
  final LocalSession _session;

  @override
  Future<Profile?> me() async {
    final id = _session.userId;
    if (id == null) return null;
    final row = await _store.byId(LocalStore.profiles, id);
    return row == null ? null : Profile.fromJson(row);
  }

  @override
  Future<Profile> updateName(String displayName) async {
    final row = await _store.patch(
      LocalStore.profiles,
      _session.requireUserId(),
      (row) => {...row, 'display_name': displayName.trim()},
    );
    if (row == null) {
      throw const TastingException('Din profil findes ikke.');
    }
    return Profile.fromJson(row);
  }
}
