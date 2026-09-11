import '../models/rating.dart';
import '../models/tasting_config.dart';
import '../models/tasting_item.dart';

/// Settles a guess against what was actually in the glass.
///
/// This is the Dart twin of `public.score_rating()` in
/// `supabase/migrations/0001_init.sql`. The two must agree, because an evening
/// hosted on a phone today and re-opened against Supabase later should show the
/// same points. The rules are the ones printed on the guess sheet:
///
/// * **duft / smag** — 1 point per matched note, capped at the category's points
/// * **drue** — all or nothing
/// * **pris** — full within 25 kr., two thirds within 50, one third within 100
/// * **alkohol** — exact is full, within 1 % is 1 point
/// * **årgang** — exact is full, within 2 years is 1 point
/// * **land og region** — the country is worth the category's points minus two
///   (never less than one); the region takes the remainder
/// * **ekstra** — all or nothing
///
/// Only the host runs this, and only at reveal. A guest's device never scores
/// its own guess, exactly as the database never let it.
class GuessScorer {
  const GuessScorer._();

  static ({Map<GuessCategory, ({int got, int max})> rows, int total}) score({
    required TastingItem item,
    required Rating rating,
    required TastingConfig config,
  }) {
    final rows = <GuessCategory, ({int got, int max})>{};
    var total = 0;

    for (final category in GuessCategory.values) {
      if (!config.isOn(category)) continue;

      final rule = config.cats[category]!;
      final max = rule.points;
      final got = switch (category) {
        GuessCategory.duft => _overlap(rating.guessAromas, item.aromas, max),
        GuessCategory.smag => _overlap(rating.guessFlavours, item.flavours, max),
        GuessCategory.drue => _exact(rating.guessGrape, item.grape, max),
        GuessCategory.pris => _byNearness(rating.guessPrice, item.price, max),
        GuessCategory.alkohol => _abv(rating.guessAbv, item.abv, max),
        GuessCategory.argang => _vintage(rating.guessVintage, item.vintage, max),
        GuessCategory.region => _exact(
              rating.guessCountry,
              item.country,
              rule.countryPoints,
            ) +
            _exact(rating.guessRegion, item.region, rule.regionPoints),
        GuessCategory.ekstra => _exact(rating.guessExtra, item.extra, max),
      };

      rows[category] = (got: got, max: max);
      total += got;
    }

    return (rows: rows, total: total);
  }

  /// 1 point per note that was actually there, up to the cap.
  static int _overlap(List<String> guess, List<String> truth, int cap) {
    final actual = truth.toSet();
    final hits = guess.where(actual.contains).length;
    return hits < cap ? hits : cap;
  }

  /// Case- and whitespace-tolerant, because a guest may have typed their own.
  static int _exact(String? guess, String? truth, int points) {
    if (guess == null || truth == null) return 0;
    return guess.trim().toLowerCase() == truth.trim().toLowerCase()
        ? points
        : 0;
  }

  static int _byNearness(double? guess, double? truth, int max) {
    if (guess == null || truth == null) return 0;
    final distance = (guess - truth).abs();
    if (distance <= 25) return max;
    if (distance <= 50) return (max * 2 / 3).ceil();
    if (distance <= 100) return (max / 3).ceil();
    return 0;
  }

  static int _abv(double? guess, double? truth, int max) {
    if (guess == null || truth == null) return 0;
    final distance = (guess - truth).abs();
    if (distance < 0.05) return max;
    return distance <= 1 ? 1 : 0;
  }

  static int _vintage(int? guess, int? truth, int max) {
    if (guess == null || truth == null) return 0;
    final distance = (guess - truth).abs();
    if (distance == 0) return max;
    return distance <= 2 ? 1 : 0;
  }
}
