import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/data/models/rating.dart';
import 'package:i_glasset/data/models/tasting_config.dart';
import 'package:i_glasset/data/models/tasting_item.dart';
import 'package:i_glasset/data/scoring/guess_scorer.dart';

/// The rules here must agree with `public.score_rating()` in
/// `supabase/migrations/0001_init.sql`. An evening hosted on a phone today and
/// re-opened against Supabase later should award the same points.
void main() {
  const truth = TastingItem(
    id: 'i1',
    tastingId: 't1',
    position: 3,
    isRevealed: true,
    name: 'Barbaresco 2021',
    grape: 'Nebbiolo',
    country: 'Italien',
    region: 'Piemonte',
    vintage: 2021,
    abv: 14.0,
    price: 315,
    extra: 'Tre år på store fade',
    aromas: ['Kirsebær', 'Rose', 'Tjære', 'Tobak'],
    flavours: ['Rød frugt', 'Stramme tanniner', 'Lakrids'],
  );

  Rating guess({
    List<String> aromas = const [],
    List<String> flavours = const [],
    String? grape,
    String? country,
    String? region,
    String? extra,
    double? price,
    double? abv,
    int? vintage,
  }) =>
      Rating(
        id: 'r1',
        tastingItemId: 'i1',
        userId: 'u1',
        guessAromas: aromas,
        guessFlavours: flavours,
        guessGrape: grape,
        guessCountry: country,
        guessRegion: region,
        guessExtra: extra,
        guessPrice: price,
        guessAbv: abv,
        guessVintage: vintage,
      );

  int points(Rating rating, [TastingConfig config = const TastingConfig()]) =>
      GuessScorer.score(item: truth, rating: rating, config: config).total;

  group('notes', () {
    test('one point per matched note', () {
      expect(points(guess(aromas: ['Kirsebær', 'Rose'])), 2);
    });

    test('capped at the category points', () {
      // All four are right, but the category is only worth three.
      expect(
        points(guess(aromas: ['Kirsebær', 'Rose', 'Tjære', 'Tobak'])),
        3,
      );
    });

    test('wrong notes earn nothing and cost nothing', () {
      expect(points(guess(aromas: ['Vanilje', 'Peber'])), 0);
      expect(points(guess(aromas: ['Kirsebær', 'Vanilje'])), 1);
    });
  });

  group('grape', () {
    test('all or nothing', () {
      expect(points(guess(grape: 'Nebbiolo')), 3);
      expect(points(guess(grape: 'Barbera')), 0);
    });

    test('a typed-in guess still counts, whatever the casing', () {
      expect(points(guess(grape: ' nebbiolo ')), 3);
    });
  });

  group('price', () {
    test('tiers by how close you got', () {
      expect(points(guess(price: 300)), 3); // within 25
      expect(points(guess(price: 270)), 2); // within 50
      expect(points(guess(price: 230)), 1); // within 100
      expect(points(guess(price: 100)), 0); // further out
    });

    test('the boundaries are inclusive, as the SQL has them', () {
      expect(points(guess(price: 290)), 3); // exactly 25 away
      expect(points(guess(price: 265)), 2); // exactly 50 away
      expect(points(guess(price: 215)), 1); // exactly 100 away
    });
  });

  group('alcohol', () {
    test('exact wins the category, close wins one', () {
      expect(points(guess(abv: 14.0)), 3);
      expect(points(guess(abv: 13.5)), 1);
      expect(points(guess(abv: 15.0)), 1);
      expect(points(guess(abv: 16.0)), 0);
    });
  });

  group('vintage', () {
    test('exact wins the category, within two years wins one', () {
      expect(points(guess(vintage: 2021)), 3);
      expect(points(guess(vintage: 2019)), 1);
      expect(points(guess(vintage: 2023)), 1);
      expect(points(guess(vintage: 2015)), 0);
    });
  });

  group('country and region', () {
    test('the country is worth the category minus two, the region the rest', () {
      // Region defaults to five points: three for the country, two for the region.
      expect(points(guess(country: 'Italien')), 3);
      expect(points(guess(region: 'Piemonte')), 2);
      expect(points(guess(country: 'Italien', region: 'Piemonte')), 5);
      expect(points(guess(country: 'Frankrig', region: 'Piemonte')), 2);
    });

    test('a small category still pays at least one for the country', () {
      final config = const TastingConfig()
          .withCategory(GuessCategory.region, const CategoryRule(on: true, points: 2));
      expect(points(guess(country: 'Italien'), config), 1);
      expect(points(guess(region: 'Piemonte'), config), 1);
    });
  });

  test('the extraordinary is all or nothing', () {
    expect(points(guess(extra: 'Tre år på store fade')), 3);
    expect(points(guess(extra: 'Økologisk')), 0);
  });

  test('categories the host switched off score nothing', () {
    final config = const TastingConfig().withCategory(
      GuessCategory.drue,
      const CategoryRule(on: false, points: 3),
    );
    final scored = GuessScorer.score(
      item: truth,
      rating: guess(grape: 'Nebbiolo'),
      config: config,
    );

    expect(scored.total, 0);
    expect(scored.rows.containsKey(GuessCategory.drue), isFalse);
  });

  test('the whole game off scores nothing at all', () {
    final scored = GuessScorer.score(
      item: truth,
      rating: guess(grape: 'Nebbiolo', country: 'Italien', price: 315),
      config: const TastingConfig(guessOn: false),
    );
    expect(scored.total, 0);
    expect(scored.rows, isEmpty);
  });

  test('a perfect guess takes everything in play', () {
    const config = TastingConfig();
    final perfect = guess(
      aromas: ['Kirsebær', 'Rose', 'Tjære'],
      flavours: ['Rød frugt', 'Stramme tanniner', 'Lakrids'],
      grape: 'Nebbiolo',
      country: 'Italien',
      region: 'Piemonte',
      extra: 'Tre år på store fade',
      price: 315,
      abv: 14.0,
      vintage: 2021,
    );

    expect(points(perfect, config), config.pointsInPlay);
  });

  test('an empty guess scores nothing but reports every category', () {
    final scored = GuessScorer.score(
      item: truth,
      rating: guess(),
      config: const TastingConfig(),
    );

    expect(scored.total, 0);
    expect(scored.rows.length, GuessCategory.values.length);
    expect(scored.rows.values.every((row) => row.got == 0), isTrue);
  });
}
