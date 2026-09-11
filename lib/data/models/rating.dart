import 'tasting_config.dart';

/// What one person said about one glass: a score, free notes, and — when the
/// host turned the guessing game on — their guess at what it was.
///
/// [score] is always on the 1–10 scale, whatever scale the tasting displays.
class Rating {
  const Rating({
    required this.id,
    required this.tastingItemId,
    required this.userId,
    this.score,
    this.notes,
    this.guessAromas = const [],
    this.guessFlavours = const [],
    this.guessGrape,
    this.guessCountry,
    this.guessRegion,
    this.guessExtra,
    this.guessPrice,
    this.guessAbv,
    this.guessVintage,
    this.points = const {},
    this.pointsTotal,
    this.submittedAt,
  });

  final String id;
  final String tastingItemId;
  final String userId;

  final double? score;
  final String? notes;

  final List<String> guessAromas;
  final List<String> guessFlavours;
  final String? guessGrape;
  final String? guessCountry;
  final String? guessRegion;
  final String? guessExtra;
  final double? guessPrice;
  final double? guessAbv;
  final int? guessVintage;

  /// Settled by the server at reveal. Never written from the app.
  final Map<GuessCategory, ({int got, int max})> points;
  final int? pointsTotal;

  final DateTime? submittedAt;

  bool get isSubmitted => submittedAt != null;

  /// Which categories this person has actually answered — drives the
  /// "3 af 8 kategorier gættet" line on the live screen.
  bool hasAnswered(GuessCategory category) => switch (category) {
        GuessCategory.duft => guessAromas.isNotEmpty,
        GuessCategory.smag => guessFlavours.isNotEmpty,
        GuessCategory.drue => guessGrape != null,
        GuessCategory.pris => guessPrice != null,
        GuessCategory.alkohol => guessAbv != null,
        GuessCategory.argang => guessVintage != null,
        GuessCategory.region => guessCountry != null || guessRegion != null,
        GuessCategory.ekstra => guessExtra != null,
      };

  int answeredCount(TastingConfig config) =>
      config.activeCategories.where(hasAnswered).length;

  factory Rating.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as Map<String, dynamic>?;
    return Rating(
      id: json['id'] as String,
      tastingItemId: json['tasting_item_id'] as String,
      userId: json['user_id'] as String,
      score: _double(json['score']),
      notes: json['notes'] as String?,
      guessAromas: (json['guess_aromas'] as List?)?.cast<String>() ?? const [],
      guessFlavours:
          (json['guess_flavours'] as List?)?.cast<String>() ?? const [],
      guessGrape: json['guess_grape'] as String?,
      guessCountry: json['guess_country'] as String?,
      guessRegion: json['guess_region'] as String?,
      guessExtra: json['guess_extra'] as String?,
      guessPrice: _double(json['guess_price']),
      guessAbv: _double(json['guess_abv']),
      guessVintage: (json['guess_vintage'] as num?)?.toInt(),
      points: rawPoints == null
          ? const {}
          : {
              for (final entry in rawPoints.entries)
                GuessCategory.fromKey(entry.key): (
                  got: ((entry.value as Map)['got'] as num).toInt(),
                  max: ((entry.value as Map)['max'] as num).toInt(),
                ),
            },
      pointsTotal: (json['points_total'] as num?)?.toInt(),
      submittedAt: json['submitted_at'] == null
          ? null
          : DateTime.parse(json['submitted_at'] as String).toLocal(),
    );
  }

  /// `points` and `points_total` are deliberately absent: the database rejects
  /// them from a client write and settles them itself at reveal.
  Map<String, dynamic> toUpsert() => {
        'tasting_item_id': tastingItemId,
        'user_id': userId,
        'score': score,
        'notes': notes,
        'guess_aromas': guessAromas,
        'guess_flavours': guessFlavours,
        'guess_grape': guessGrape,
        'guess_country': guessCountry,
        'guess_region': guessRegion,
        'guess_extra': guessExtra,
        'guess_price': guessPrice,
        'guess_abv': guessAbv,
        'guess_vintage': guessVintage,
        'submitted_at': submittedAt?.toUtc().toIso8601String(),
      };

  Rating copyWith({
    double? score,
    String? notes,
    List<String>? guessAromas,
    List<String>? guessFlavours,
    String? guessGrape,
    String? guessCountry,
    String? guessRegion,
    String? guessExtra,
    double? guessPrice,
    double? guessAbv,
    int? guessVintage,
    DateTime? submittedAt,
    bool clearSubmitted = false,
    bool clearGrape = false,
    bool clearCountry = false,
    bool clearRegion = false,
    bool clearExtra = false,
  }) =>
      Rating(
        id: id,
        tastingItemId: tastingItemId,
        userId: userId,
        score: score ?? this.score,
        notes: notes ?? this.notes,
        guessAromas: guessAromas ?? this.guessAromas,
        guessFlavours: guessFlavours ?? this.guessFlavours,
        guessGrape: clearGrape ? null : (guessGrape ?? this.guessGrape),
        guessCountry: clearCountry ? null : (guessCountry ?? this.guessCountry),
        guessRegion: clearRegion ? null : (guessRegion ?? this.guessRegion),
        guessExtra: clearExtra ? null : (guessExtra ?? this.guessExtra),
        guessPrice: guessPrice ?? this.guessPrice,
        guessAbv: guessAbv ?? this.guessAbv,
        guessVintage: guessVintage ?? this.guessVintage,
        points: points,
        pointsTotal: pointsTotal,
        submittedAt: clearSubmitted ? null : (submittedAt ?? this.submittedAt),
      );

  static Rating empty({
    required String id,
    required String tastingItemId,
    required String userId,
  }) =>
      Rating(id: id, tastingItemId: tastingItemId, userId: userId);
}

double? _double(Object? value) => switch (value) {
      null => null,
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
