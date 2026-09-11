class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.avatarSeed,
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String avatarSeed;
  final DateTime? createdAt;

  /// "Sofie Bak" → "SB", "Martin" → "MA".
  String get initials {
    final parts =
        displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return _take(parts.first, 2);
    return '${_take(parts.first, 1)}${_take(parts.last, 1)}';
  }

  /// The part of the name the roster shows.
  String get firstName => displayName.trim().split(RegExp(r'\s+')).first;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        displayName: json['display_name'] as String? ?? 'Gæst',
        avatarSeed: json['avatar_seed'] as String? ?? json['id'] as String,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

String _take(String value, int count) =>
    (value.length <= count ? value : value.substring(0, count)).toUpperCase();
