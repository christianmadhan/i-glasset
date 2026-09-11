import 'tasting_config.dart';

enum TastingStatus {
  /// The host is still building it; nobody can join.
  draft('draft'),

  /// Open for joining; the room is in the lobby.
  lobby('lobby'),

  /// Glasses are being poured.
  live('live'),

  /// Over and archived.
  finished('finished');

  const TastingStatus(this.wire);
  final String wire;

  static TastingStatus fromWire(String? value) => TastingStatus.values
      .firstWhere((s) => s.wire == value, orElse: () => TastingStatus.draft);

  bool get isOpen => this == lobby || this == live;
}

class Tasting {
  const Tasting({
    required this.id,
    required this.hostId,
    required this.title,
    required this.category,
    required this.status,
    required this.joinCode,
    required this.currentPosition,
    required this.config,
    required this.createdAt,
    this.groupId,
    this.groupName,
    this.hostName,
    this.theme,
    this.description,
    this.scheduledFor,
    this.finishedAt,
    this.itemCount = 0,
    this.participantCount = 0,
  });

  final String id;
  final String? groupId;
  final String? groupName;
  final String hostId;
  final String? hostName;
  final String title;
  final String? theme;
  final String? description;
  final String category;
  final TastingStatus status;
  final String joinCode;

  /// Which glass the room is on. 0 means still in the lobby.
  final int currentPosition;

  final TastingConfig config;
  final DateTime? scheduledFor;
  final DateTime? finishedAt;
  final DateTime createdAt;

  final int itemCount;
  final int participantCount;

  bool isHostedBy(String? userId) => userId != null && userId == hostId;

  RatingScale get scale => config.scale;

  factory Tasting.fromJson(
    Map<String, dynamic> json, {
    int itemCount = 0,
    int participantCount = 0,
  }) {
    final group = json['groups'] as Map<String, dynamic>?;
    final host = json['profiles'] as Map<String, dynamic>?;
    return Tasting(
      id: json['id'] as String,
      groupId: json['group_id'] as String?,
      groupName: group?['name'] as String?,
      hostId: json['host_id'] as String,
      hostName: host?['display_name'] as String?,
      title: json['title'] as String,
      theme: json['theme'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'Vin',
      status: TastingStatus.fromWire(json['status'] as String?),
      joinCode: json['join_code'] as String? ?? '',
      currentPosition: (json['current_position'] as num?)?.toInt() ?? 0,
      config: TastingConfig.parse(json['config']),
      scheduledFor: _date(json['scheduled_for']),
      finishedAt: _date(json['finished_at']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      itemCount: itemCount,
      participantCount: participantCount,
    );
  }

  Map<String, dynamic> toInsert() => {
        'host_id': hostId,
        if (groupId != null) 'group_id': groupId,
        'title': title,
        if (theme != null && theme!.isNotEmpty) 'theme': theme,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'category': category,
        'status': status.wire,
        if (scheduledFor != null)
          'scheduled_for': scheduledFor!.toUtc().toIso8601String(),
        'config': config.toJson(),
      };

  Tasting copyWith({
    String? title,
    String? theme,
    String? description,
    String? category,
    TastingStatus? status,
    int? currentPosition,
    TastingConfig? config,
    DateTime? scheduledFor,
    DateTime? finishedAt,
    int? itemCount,
    int? participantCount,
  }) =>
      Tasting(
        id: id,
        groupId: groupId,
        groupName: groupName,
        hostId: hostId,
        hostName: hostName,
        title: title ?? this.title,
        theme: theme ?? this.theme,
        description: description ?? this.description,
        category: category ?? this.category,
        status: status ?? this.status,
        joinCode: joinCode,
        currentPosition: currentPosition ?? this.currentPosition,
        config: config ?? this.config,
        scheduledFor: scheduledFor ?? this.scheduledFor,
        finishedAt: finishedAt ?? this.finishedAt,
        createdAt: createdAt,
        itemCount: itemCount ?? this.itemCount,
        participantCount: participantCount ?? this.participantCount,
      );
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();
