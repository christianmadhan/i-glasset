import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/data/models/tasting_config.dart';

void main() {
  group('TastingConfig', () {
    test('round-trips through the jsonb shape the database stores', () {
      final original = const TastingConfig().copyWith(
        blind: 'Kun navnet skjult',
        reveal: 'Til sidst',
        scale: RatingScale.hundredPoint,
        showOthers: 'Straks',
        requireNotes: true,
        guessOn: true,
      ).withCategory(
        GuessCategory.drue,
        const CategoryRule(on: false, points: 7),
      );

      final restored = TastingConfig.fromJson(original.toJson());

      expect(restored.blind, 'Kun navnet skjult');
      expect(restored.reveal, 'Til sidst');
      expect(restored.scale, RatingScale.hundredPoint);
      expect(restored.showOthers, 'Straks');
      expect(restored.requireNotes, isTrue);
      expect(restored.cats[GuessCategory.drue]!.on, isFalse);
      expect(restored.cats[GuessCategory.drue]!.points, 7);
    });

    test('a missing config falls back to the defaults', () {
      final config = TastingConfig.parse(null);
      expect(config.guessOn, isTrue);
      expect(config.scale, RatingScale.tenPoint);
      expect(config.pointsInPlay, 26); // 7 × 3 + region 5
    });

    test('points in play counts only the categories that are switched on', () {
      const config = TastingConfig(cats: {
        GuessCategory.duft: CategoryRule(on: true, points: 3),
        GuessCategory.smag: CategoryRule(on: false, points: 3),
        GuessCategory.drue: CategoryRule(on: true, points: 4),
        GuessCategory.pris: CategoryRule(on: false, points: 3),
        GuessCategory.alkohol: CategoryRule(on: false, points: 3),
        GuessCategory.argang: CategoryRule(on: false, points: 3),
        GuessCategory.region: CategoryRule(on: false, points: 5),
        GuessCategory.ekstra: CategoryRule(on: false, points: 3),
      });

      expect(config.pointsInPlay, 7);
      expect(config.activeCategories,
          [GuessCategory.duft, GuessCategory.drue]);
    });

    test('turning the whole game off silences every category', () {
      const config = TastingConfig(guessOn: false);
      expect(config.isOn(GuessCategory.duft), isFalse);
      expect(config.pointsInPlay, 0);
      expect(config.activeCategories, isEmpty);
    });

    test('region splits its points between country and region', () {
      const five = CategoryRule(on: true, points: 5);
      expect(five.countryPoints, 3);
      expect(five.regionPoints, 2);

      // The country is always worth at least one point, however small the
      // category is set.
      const two = CategoryRule(on: true, points: 2);
      expect(two.countryPoints, 1);
      expect(two.regionPoints, 1);
    });

    test('rule text states what each category is worth', () {
      const config = TastingConfig();
      expect(config.ruleText(GuessCategory.duft), '1 pt pr. note · max 3');
      expect(config.ruleText(GuessCategory.pris), '3, 2, 1 pt efter nærhed');
      expect(config.ruleText(GuessCategory.argang),
          '3 pt præcis · 1 pt inden for 2 år');
      expect(config.ruleText(GuessCategory.region), '3 pt land · 2 pt region');
    });
  });

  group('RatingScale', () {
    test('stores on 1–10 whatever scale the tasting shows', () {
      const hundred = RatingScale.hundredPoint;
      expect(hundred.display(8.6), 86);
      expect(hundred.store(86), closeTo(8.6, 0.001));

      const ten = RatingScale.tenPoint;
      expect(ten.display(8.6), 8.6);
      expect(ten.store(8.6), 8.6);
    });

    test('formats scores the Danish way', () {
      expect(RatingScale.tenPoint.format(8.6), '8,6');
      expect(RatingScale.tenPoint.format(7.0), '7,0');
      expect(RatingScale.hundredPoint.format(8.6), '86');
    });

    test('accepts both the en-dash and hyphen spellings from the wire', () {
      expect(RatingScale.fromWire('1-100'), RatingScale.hundredPoint);
      expect(RatingScale.fromWire('1–100'), RatingScale.hundredPoint);
      expect(RatingScale.fromWire('1-10'), RatingScale.tenPoint);
      expect(RatingScale.fromWire(null), RatingScale.tenPoint);
    });
  });
}
