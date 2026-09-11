import '../../data/repositories/tasting_repository.dart';

/// What someone's ratings say about their palate.
///
/// The design shows a written summary, a set of pattern meters, and a
/// recommendation. All three are derived here from the notes and scores in the
/// archive — the app never claims a pattern it can't point at real ratings for,
/// which is why everything is gated on a minimum number of tastings.
class TasteProfile {
  const TasteProfile({
    required this.sampleSize,
    required this.traits,
    required this.favouriteRegion,
    required this.favouriteGrape,
    required this.averageScore,
    required this.highScoringGrapes,
  });

  /// How many scored, revealed glasses this is built on.
  final int sampleSize;

  /// Descriptors the person tends to record, with how often — 0…1.
  final List<({String label, double frequency})> traits;

  final String? favouriteRegion;
  final String? favouriteGrape;
  final double? averageScore;

  /// Grapes this person scores above their own average.
  final List<String> highScoringGrapes;

  /// Under a handful of glasses there's nothing honest to say.
  bool get isEmpty => sampleSize < 5;

  /// "Mellemfyldig, høj syre, røde frugter"
  String get headlineTraits => traits.isEmpty
      ? 'Endnu ingen mønstre'
      : traits.take(3).map((t) => t.label.toLowerCase()).join(', ');

  /// The written summary at the top of the taste-profile screen.
  String get summary {
    if (isEmpty) {
      return 'Når du har bedømt en håndfuld glas mere, tegner vi et billede '
          'af, hvad du holder af.';
    }
    final parts = <String>[
      'Du foretrækker ${traits.take(2).map((t) => t.label.toLowerCase()).join(' og ')}',
      if (favouriteGrape != null) 'især i ${favouriteGrape!}',
      if (favouriteRegion != null) 'fra $favouriteRegion',
    ];
    return '${parts.join(', ')}.';
  }

  String get detail {
    if (isEmpty) return '';
    final grapes = highScoringGrapes.take(2).join(' og ');
    if (grapes.isEmpty) {
      return 'Bygget på $sampleSize bedømte glas.';
    }
    return '$grapes får dine højeste karakterer. '
        'Bygget på $sampleSize bedømte glas.';
  }

  static const empty = TasteProfile(
    sampleSize: 0,
    traits: [],
    favouriteRegion: null,
    favouriteGrape: null,
    averageScore: null,
    highScoringGrapes: [],
  );

  factory TasteProfile.from(List<ArchiveEntry> archive) {
    final scored =
        archive.where((e) => e.rating.score != null).toList();
    if (scored.length < 5) {
      return TasteProfile.empty.copyWith(sampleSize: scored.length);
    }

    final average =
        scored.fold<double>(0, (sum, e) => sum + e.rating.score!) / scored.length;

    // Which descriptors show up in the glasses this person liked. Weighted
    // towards their better scores, so "high acid" only counts as a preference
    // if they actually rated those wines well.
    final liked = scored.where((e) => e.rating.score! >= average).toList();
    final counts = <String, int>{};
    for (final entry in liked) {
      for (final note in {...entry.item.flavours, ...entry.item.aromas}) {
        counts[note] = (counts[note] ?? 0) + 1;
      }
    }

    final traits = counts.entries
        .map((e) => (label: e.key, frequency: e.value / liked.length))
        .toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));

    // Grapes and regions they score above their own average.
    final byGrape = <String, List<double>>{};
    final byRegion = <String, List<double>>{};
    for (final entry in scored) {
      final grape = entry.item.grape;
      final region = entry.item.region;
      if (grape != null && grape.isNotEmpty) {
        (byGrape[grape] ??= []).add(entry.rating.score!);
      }
      if (region != null && region.isNotEmpty) {
        (byRegion[region] ??= []).add(entry.rating.score!);
      }
    }

    String? best(Map<String, List<double>> groups) {
      final ranked = groups.entries
          .where((e) => e.value.length >= 2)
          .map((e) => (
                key: e.key,
                mean: e.value.reduce((a, b) => a + b) / e.value.length,
              ))
          .toList()
        ..sort((a, b) => b.mean.compareTo(a.mean));
      return ranked.isEmpty ? null : ranked.first.key;
    }

    final highScoring = byGrape.entries
        .where((e) =>
            e.value.length >= 2 &&
            e.value.reduce((a, b) => a + b) / e.value.length > average)
        .map((e) => e.key)
        .toList();

    return TasteProfile(
      sampleSize: scored.length,
      traits: traits.take(6).toList(),
      favouriteRegion: best(byRegion),
      favouriteGrape: best(byGrape),
      averageScore: average,
      highScoringGrapes: highScoring,
    );
  }

  TasteProfile copyWith({int? sampleSize}) => TasteProfile(
        sampleSize: sampleSize ?? this.sampleSize,
        traits: traits,
        favouriteRegion: favouriteRegion,
        favouriteGrape: favouriteGrape,
        averageScore: averageScore,
        highScoringGrapes: highScoringGrapes,
      );

  /// Frequency as the design words it.
  static String frequencyLabel(double frequency) => switch (frequency) {
        >= 0.8 => 'meget ofte',
        >= 0.6 => 'ofte',
        >= 0.4 => 'af og til',
        >= 0.2 => 'sjældent',
        _ => 'næsten aldrig',
      };
}
