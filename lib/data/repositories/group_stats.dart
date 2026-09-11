import '../models/profile.dart';
import '../models/rating.dart';
import '../models/tasting.dart';
import '../models/tasting_item.dart';

/// One scored glass, with who scored it — the raw material for every number on
/// the group screen.
typedef GroupRatingRow = ({
  Rating rating,
  Profile taster,
  TastingItem item,
  Tasting tasting,
});

/// Everything the "Gruppe" screen puts on the board, computed from the group's
/// finished tastings rather than stored anywhere.
class GroupStats {
  const GroupStats({
    required this.leaderboard,
    required this.spendByEvening,
    required this.spendTotal,
    required this.bottleCount,
    required this.priceAccuracy,
    required this.records,
    required this.tastingCount,
    required this.productCount,
    required this.average,
    required this.mostActiveHost,
  });

  final List<LeaderboardEntry> leaderboard;
  final List<({String name, double amount})> spendByEvening;
  final double spendTotal;
  final int bottleCount;

  /// Average kroner between a person's price guess and the real price.
  final List<({String name, double distance})> priceAccuracy;

  final List<({String value, String label})> records;
  final int tastingCount;
  final int productCount;
  final double? average;
  final String? mostActiveHost;

  double get averageBottlePrice =>
      bottleCount == 0 ? 0 : spendTotal / bottleCount;

  static const empty = GroupStats(
    leaderboard: [],
    spendByEvening: [],
    spendTotal: 0,
    bottleCount: 0,
    priceAccuracy: [],
    records: [],
    tastingCount: 0,
    productCount: 0,
    average: null,
    mostActiveHost: null,
  );

  bool get isEmpty => productCount == 0;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.points,
    required this.tastings,
  });

  final String userId;
  final String name;
  final int points;
  final int tastings;

  String get meta => '$tastings ${tastings == 1 ? 'smagning' : 'smagninger'}';
}

/// Where the raw rows for a group's numbers come from.
///
/// The arithmetic below is shared; only the query differs between backends.
abstract interface class GroupStatsSource {
  /// Every rating anyone gave on a revealed glass in this group's tastings.
  Future<List<GroupRatingRow>> groupRatings(String groupId);
}

/// Turns those rows into the board the group screen draws.
class GroupStatsCalculator {
  const GroupStatsCalculator();

  GroupStats summarise(List<GroupRatingRow> rows, List<Tasting> tastings) {
    if (rows.isEmpty) {
      return GroupStats.empty.copyWith(tastingCount: tastings.length);
    }

    // --- leaderboard: guess points, and how many nights each person showed up
    final points = <String, int>{};
    final names = <String, String>{};
    final nights = <String, Set<String>>{};
    for (final row in rows) {
      final id = row.taster.id;
      names[id] = row.taster.firstName;
      points[id] = (points[id] ?? 0) + (row.rating.pointsTotal ?? 0);
      (nights[id] ??= {}).add(row.tasting.id);
    }
    final leaderboard = points.entries
        .map((e) => LeaderboardEntry(
              userId: e.key,
              name: names[e.key] ?? 'Gæst',
              points: e.value,
              tastings: nights[e.key]?.length ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.points.compareTo(a.points));

    // --- spend: each bottle counted once, not once per taster
    final bottles = <String, TastingItem>{};
    final bottleTasting = <String, Tasting>{};
    for (final row in rows) {
      bottles[row.item.id] = row.item;
      bottleTasting[row.item.id] = row.tasting;
    }

    final spendPerEvening = <String, double>{};
    var spendTotal = 0.0;
    for (final entry in bottles.entries) {
      final price = entry.value.price;
      if (price == null) continue;
      final title = bottleTasting[entry.key]!.title;
      spendPerEvening[title] = (spendPerEvening[title] ?? 0) + price;
      spendTotal += price;
    }
    final spendByEvening = spendPerEvening.entries
        .map((e) => (name: e.key, amount: e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // --- who guesses the price closest
    final priceError = <String, List<double>>{};
    for (final row in rows) {
      final guess = row.rating.guessPrice;
      final actual = row.item.price;
      if (guess == null || actual == null) continue;
      (priceError[row.taster.id] ??= []).add((guess - actual).abs());
    }
    final priceAccuracy = priceError.entries
        .map((e) => (
              name: names[e.key] ?? 'Gæst',
              distance: e.value.reduce((a, b) => a + b) / e.value.length,
            ))
        .toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    // --- club numbers
    final scored = rows.where((r) => r.rating.score != null).toList();
    final average = scored.isEmpty
        ? null
        : scored.fold<double>(0, (sum, r) => sum + r.rating.score!) /
            scored.length;

    final hostCounts = <String, int>{};
    for (final tasting in tastings) {
      final host = tasting.hostName;
      if (host != null) hostCounts[host] = (hostCounts[host] ?? 0) + 1;
    }
    final mostActiveHost = hostCounts.isEmpty
        ? null
        : hostCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return GroupStats(
      leaderboard: leaderboard,
      spendByEvening: spendByEvening,
      spendTotal: spendTotal,
      bottleCount: bottles.length,
      priceAccuracy: priceAccuracy,
      records: _records(rows, bottles, bottleTasting, names),
      tastingCount: tastings.length,
      productCount: bottles.length,
      average: average,
      mostActiveHost: mostActiveHost,
    );
  }

  /// "Rekorder" — the four bragging rights the design puts at the bottom.
  List<({String value, String label})> _records(
    List<GroupRatingRow> rows,
    Map<String, TastingItem> bottles,
    Map<String, Tasting> bottleTasting,
    Map<String, String> names,
  ) {
    final records = <({String value, String label})>[];

    // Most expensive bottle the club has opened.
    final priced = bottles.values.where((b) => b.price != null).toList()
      ..sort((a, b) => b.price!.compareTo(a.price!));
    if (priced.isNotEmpty) {
      final top = priced.first;
      records.add((
        value: top.displayName,
        label: 'dyreste flaske · ${top.formattedPrice} · '
            '${bottleTasting[top.id]?.title ?? ''}',
      ));
    }

    // Best at naming the grape.
    final grapeHits = <String, ({int hits, int tries})>{};
    for (final row in rows) {
      if (row.item.grape == null || row.rating.guessGrape == null) continue;
      final current = grapeHits[row.taster.id] ?? (hits: 0, tries: 0);
      grapeHits[row.taster.id] = (
        hits: current.hits + (row.rating.guessGrape == row.item.grape ? 1 : 0),
        tries: current.tries + 1,
      );
    }
    final bestGrape = grapeHits.entries
        .where((e) => e.value.tries >= 3)
        .fold<MapEntry<String, ({int hits, int tries})>?>(null, (best, e) {
      if (best == null) return e;
      return e.value.hits / e.value.tries > best.value.hits / best.value.tries
          ? e
          : best;
    });
    if (bestGrape != null) {
      final pct =
          (bestGrape.value.hits / bestGrape.value.tries * 100).round();
      records.add((
        value: names[bestGrape.key] ?? 'Gæst',
        label: 'bedst til drue · $pct % rigtige gæt',
      ));
    }

    // Most generous and harshest judge.
    final averages = <String, List<double>>{};
    for (final row in rows) {
      if (row.rating.score == null) continue;
      (averages[row.taster.id] ??= []).add(row.rating.score!);
    }
    final means = averages.entries
        .where((e) => e.value.length >= 3)
        .map((e) => (
              id: e.key,
              mean: e.value.reduce((a, b) => a + b) / e.value.length,
            ))
        .toList()
      ..sort((a, b) => b.mean.compareTo(a.mean));

    if (means.isNotEmpty) {
      String score(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
      records.add((
        value: names[means.first.id] ?? 'Gæst',
        label: 'mest generøs · ${score(means.first.mean)} i snit',
      ));
      if (means.length > 1) {
        records.add((
          value: names[means.last.id] ?? 'Gæst',
          label: 'hårdeste dommer · ${score(means.last.mean)} i snit',
        ));
      }
    }

    return records;
  }
}

extension on GroupStats {
  GroupStats copyWith({int? tastingCount}) => GroupStats(
        leaderboard: leaderboard,
        spendByEvening: spendByEvening,
        spendTotal: spendTotal,
        bottleCount: bottleCount,
        priceAccuracy: priceAccuracy,
        records: records,
        tastingCount: tastingCount ?? this.tastingCount,
        productCount: productCount,
        average: average,
        mostActiveHost: mostActiveHost,
      );
}
