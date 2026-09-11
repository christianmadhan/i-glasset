import 'profile.dart';

enum GroupAccess {
  open('open', 'Åben', 'alle kan tilmelde sig'),
  approval('approval', 'Efter godkendelse', 'du godkender anmodninger'),
  private('private', 'Privat', 'kun med invitation');

  const GroupAccess(this.wire, this.label, this.explanation);

  final String wire;
  final String label;
  final String explanation;

  static GroupAccess fromWire(String? value) => GroupAccess.values
      .firstWhere((a) => a.wire == value, orElse: () => GroupAccess.approval);

  static GroupAccess fromLabel(String label) => GroupAccess.values
      .firstWhere((a) => a.label == label, orElse: () => GroupAccess.approval);
}

enum MemberRole {
  owner('owner'),
  admin('admin'),
  member('member');

  const MemberRole(this.wire);
  final String wire;

  static MemberRole fromWire(String? value) => MemberRole.values
      .firstWhere((r) => r.wire == value, orElse: () => MemberRole.member);

  bool get canHost => this == owner || this == admin;
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.access,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.focus = const [],
    this.memberCount = 0,
    this.tastingCount = 0,
    this.myRole,
    this.myStatusPending = false,
  });

  final String id;
  final String name;
  final String? description;
  final List<String> focus;
  final GroupAccess access;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;

  /// Aggregates, filled in by the repository rather than stored on the row.
  final int memberCount;
  final int tastingCount;

  /// This user's standing in the group, when known.
  final MemberRole? myRole;
  final bool myStatusPending;

  bool get isMember => myRole != null && !myStatusPending;
  bool get canHost => myRole?.canHost ?? false;

  String get initials {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '??';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length < 2 ? 1 : 2).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// "12 medlemmer · 38 smagninger"
  String get meta {
    final parts = <String>[
      '$memberCount ${memberCount == 1 ? 'medlem' : 'medlemmer'}',
      if (tastingCount > 0) '$tastingCount ${tastingCount == 1 ? 'smagning' : 'smagninger'}',
      if (tastingCount == 0 && focus.isNotEmpty) focus.join(', ').toLowerCase(),
    ];
    return parts.join(' · ');
  }

  factory Group.fromJson(
    Map<String, dynamic> json, {
    int memberCount = 0,
    int tastingCount = 0,
    MemberRole? myRole,
    bool myStatusPending = false,
  }) =>
      Group(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        focus: (json['focus'] as List?)?.cast<String>() ?? const [],
        access: GroupAccess.fromWire(json['access'] as String?),
        inviteCode: json['invite_code'] as String? ?? '',
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        memberCount: memberCount,
        tastingCount: tastingCount,
        myRole: myRole,
        myStatusPending: myStatusPending,
      );

  Group copyWith({
    String? name,
    String? description,
    List<String>? focus,
    GroupAccess? access,
    int? memberCount,
    int? tastingCount,
    MemberRole? myRole,
    bool? myStatusPending,
  }) =>
      Group(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        focus: focus ?? this.focus,
        access: access ?? this.access,
        inviteCode: inviteCode,
        createdBy: createdBy,
        createdAt: createdAt,
        memberCount: memberCount ?? this.memberCount,
        tastingCount: tastingCount ?? this.tastingCount,
        myRole: myRole ?? this.myRole,
        myStatusPending: myStatusPending ?? this.myStatusPending,
      );
}

class GroupMember {
  const GroupMember({
    required this.profile,
    required this.role,
    required this.pending,
  });

  final Profile profile;
  final MemberRole role;
  final bool pending;

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        profile: Profile.fromJson(json['profiles'] as Map<String, dynamic>),
        role: MemberRole.fromWire(json['role'] as String?),
        pending: json['status'] == 'pending',
      );
}
