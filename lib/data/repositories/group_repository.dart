import '../models/group.dart';
import '../models/profile.dart';

/// Groups — the clubs that own tastings, their rosters and their standings.
///
/// See [TastingRepository] for the local/Supabase split; the same applies here.
abstract interface class GroupRepository {
  Future<List<Group>> myGroups();

  /// Groups that can be found by search. Private groups never appear here
  /// unless you are already a member.
  Future<List<Group>> discover({String query});

  Future<Group> byId(String groupId);

  Future<List<GroupMember>> members(String groupId);

  Future<Group> create({
    required String name,
    String? description,
    List<String> focus,
    GroupAccess access,
  });

  Future<Group> update(
    String groupId, {
    String? name,
    String? description,
    List<String>? focus,
    GroupAccess? access,
  });

  /// Join with an invite code. Returns the group id.
  Future<String> joinByCode(String inviteCode);

  /// Ask to join a group found by search. True when you're in immediately,
  /// false when the request is pending approval.
  Future<bool> requestMembership(String groupId);

  Future<void> approve(String groupId, String userId);

  Future<void> leave(String groupId);
}

/// The signed-in person's own record.
abstract interface class ProfileRepository {
  Future<Profile?> me();

  Future<Profile> updateName(String displayName);
}

/// A person's overall numbers, shown on the profile screen.
class ProfileStats {
  const ProfileStats({
    required this.products,
    required this.tastings,
    required this.average,
    required this.groups,
    this.memberSince,
  });

  final int products;
  final int tastings;
  final double? average;
  final int groups;
  final DateTime? memberSince;

  static const empty =
      ProfileStats(products: 0, tastings: 0, average: null, groups: 0);
}
