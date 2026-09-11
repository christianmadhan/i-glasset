import 'dart:convert';

/// The eight things a guess can be scored on, in the order the design lists
/// them. The wire keys are Danish because they are also the jsonb keys the
/// scoring function in `0001_init.sql` reads.
enum GuessCategory {
  duft('duft', 'Duft'),
  smag('smag', 'Smag'),
  drue('drue', 'Drue'),
  pris('pris', 'Pris'),
  alkohol('alkohol', 'Alkohol'),
  argang('argang', 'Årgang'),
  region('region', 'Land og region'),
  ekstra('ekstra', 'Ekstraordinært');

  const GuessCategory(this.key, this.label);

  final String key;
  final String label;

  static GuessCategory fromKey(String key) =>
      GuessCategory.values.firstWhere((c) => c.key == key);
}

class CategoryRule {
  const CategoryRule({required this.on, required this.points});

  final bool on;
  final int points;

  /// Country is worth the category's points minus two (never less than one);
  /// the region is worth whatever is left.
  int get countryPoints => (points - 2) < 1 ? 1 : points - 2;
  int get regionPoints => points - countryPoints;

  CategoryRule copyWith({bool? on, int? points}) =>
      CategoryRule(on: on ?? this.on, points: points ?? this.points);

  factory CategoryRule.fromJson(Map<String, dynamic> json) => CategoryRule(
        on: json['on'] as bool? ?? false,
        points: (json['pts'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'on': on, 'pts': points};
}

/// The rating scale the host picked. Scores are always *stored* 1–10 so that a
/// person's history stays comparable across tastings; a 1–100 tasting simply
/// presents them ten times larger.
enum RatingScale {
  tenPoint('1-10', '1–10', 10),
  hundredPoint('1-100', '1–100', 100);

  const RatingScale(this.wire, this.label, this.max);

  final String wire;
  final String label;
  final int max;

  static RatingScale fromWire(String? value) =>
      value == '1-100' || value == '1–100'
          ? RatingScale.hundredPoint
          : RatingScale.tenPoint;

  double get step => this == RatingScale.hundredPoint ? 1 : 0.1;

  /// A stored 1–10 score as shown on this scale.
  double display(double stored) =>
      this == RatingScale.hundredPoint ? (stored * 10).roundToDouble() : stored;

  /// A displayed score back to the stored 1–10 form.
  double store(double displayed) =>
      this == RatingScale.hundredPoint ? displayed / 10 : displayed;

  /// Danish formatting: comma decimal, and no decimals on the 1–100 scale.
  String format(double stored) {
    final v = display(stored);
    return this == RatingScale.hundredPoint
        ? v.round().toString()
        : v.toStringAsFixed(1).replaceAll('.', ',');
  }
}

/// "Format og regler" — everything the host chooses when creating a tasting.
/// Stored as one jsonb document because the app always reads and writes it
/// whole.
class TastingConfig {
  const TastingConfig({
    this.blind = 'Alt skjult',
    this.reveal = 'Efter hvert glas',
    this.order = 'Fast',
    this.scale = RatingScale.tenPoint,
    this.showOthers = 'Efter afsløring',
    this.timer = 'Ingen',
    this.codeMode = 'Automatisk',
    this.guests = 'Kun gruppen',
    this.requireNotes = false,
    this.guessOn = true,
    this.cats = defaultCats,
  });

  static const defaultCats = <GuessCategory, CategoryRule>{
    GuessCategory.duft: CategoryRule(on: true, points: 3),
    GuessCategory.smag: CategoryRule(on: true, points: 3),
    GuessCategory.drue: CategoryRule(on: true, points: 3),
    GuessCategory.pris: CategoryRule(on: true, points: 3),
    GuessCategory.alkohol: CategoryRule(on: true, points: 3),
    GuessCategory.argang: CategoryRule(on: true, points: 3),
    GuessCategory.region: CategoryRule(on: true, points: 5),
    GuessCategory.ekstra: CategoryRule(on: true, points: 3),
  };

  final String blind;
  final String reveal;
  final String order;
  final RatingScale scale;
  final String showOthers;
  final String timer;
  final String codeMode;
  final String guests;
  final bool requireNotes;
  final bool guessOn;
  final Map<GuessCategory, CategoryRule> cats;

  bool isOn(GuessCategory category) =>
      guessOn && (cats[category]?.on ?? false);

  int pointsFor(GuessCategory category) => cats[category]?.points ?? 0;

  /// Total points available on a single glass.
  int get pointsInPlay => GuessCategory.values
      .where(isOn)
      .fold(0, (sum, c) => sum + pointsFor(c));

  List<GuessCategory> get activeCategories =>
      GuessCategory.values.where(isOn).toList();

  factory TastingConfig.fromJson(Map<String, dynamic> json) {
    final rawCats = json['cats'] as Map<String, dynamic>? ?? const {};
    return TastingConfig(
      blind: json['blind'] as String? ?? 'Alt skjult',
      reveal: json['reveal'] as String? ?? 'Efter hvert glas',
      order: json['order'] as String? ?? 'Fast',
      scale: RatingScale.fromWire(json['scale'] as String?),
      showOthers: json['show_others'] as String? ?? 'Efter afsløring',
      timer: json['timer'] as String? ?? 'Ingen',
      codeMode: json['code_mode'] as String? ?? 'Automatisk',
      guests: json['guests'] as String? ?? 'Kun gruppen',
      requireNotes: json['require_notes'] as bool? ?? false,
      guessOn: json['guess_on'] as bool? ?? true,
      cats: {
        for (final category in GuessCategory.values)
          category: rawCats[category.key] == null
              ? defaultCats[category]!
              : CategoryRule.fromJson(
                  rawCats[category.key] as Map<String, dynamic>),
      },
    );
  }

  static TastingConfig parse(Object? raw) => switch (raw) {
        null => const TastingConfig(),
        final Map<String, dynamic> map => TastingConfig.fromJson(map),
        final String text =>
          TastingConfig.fromJson(jsonDecode(text) as Map<String, dynamic>),
        _ => const TastingConfig(),
      };

  Map<String, dynamic> toJson() => {
        'blind': blind,
        'reveal': reveal,
        'order': order,
        'scale': scale.wire,
        'show_others': showOthers,
        'timer': timer,
        'code_mode': codeMode,
        'guests': guests,
        'require_notes': requireNotes,
        'guess_on': guessOn,
        'cats': {
          for (final entry in cats.entries) entry.key.key: entry.value.toJson(),
        },
      };

  TastingConfig copyWith({
    String? blind,
    String? reveal,
    String? order,
    RatingScale? scale,
    String? showOthers,
    String? timer,
    String? codeMode,
    String? guests,
    bool? requireNotes,
    bool? guessOn,
    Map<GuessCategory, CategoryRule>? cats,
  }) =>
      TastingConfig(
        blind: blind ?? this.blind,
        reveal: reveal ?? this.reveal,
        order: order ?? this.order,
        scale: scale ?? this.scale,
        showOthers: showOthers ?? this.showOthers,
        timer: timer ?? this.timer,
        codeMode: codeMode ?? this.codeMode,
        guests: guests ?? this.guests,
        requireNotes: requireNotes ?? this.requireNotes,
        guessOn: guessOn ?? this.guessOn,
        cats: cats ?? this.cats,
      );

  TastingConfig withCategory(GuessCategory category, CategoryRule rule) =>
      copyWith(cats: {...cats, category: rule});

  /// The rule text shown beside each section of the guess sheet, so players can
  /// see what a category is worth before they spend time on it.
  String ruleText(GuessCategory category) {
    final p = pointsFor(category);
    return switch (category) {
      GuessCategory.duft => '1 pt pr. note · max $p',
      GuessCategory.smag => '1 pt pr. note · max $p',
      GuessCategory.drue => '$p pt',
      GuessCategory.pris =>
        '$p, ${(p * 2 / 3).ceil()}, ${(p / 3).ceil()} pt efter nærhed',
      GuessCategory.alkohol => '$p pt præcis · 1 pt inden for 1 %',
      GuessCategory.argang => '$p pt præcis · 1 pt inden for 2 år',
      GuessCategory.region => () {
          final rule = cats[category]!;
          return '${rule.countryPoints} pt land · ${rule.regionPoints} pt region';
        }(),
      GuessCategory.ekstra => '$p pt',
    };
  }
}
