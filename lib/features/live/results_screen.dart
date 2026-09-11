import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/models/rating.dart';
import '../../data/models/tasting_config.dart';
import '../../data/models/tasting_item.dart';

/// "Live resultater" — how the glasses rank so far, and who's winning the
/// guessing game.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.tastingId});

  final String tastingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final tasting = ref.watch(tastingProvider(tastingId)).value;
    final items = ref.watch(itemsProvider(tastingId)).value ?? const [];
    final ratings = ref.watch(ratingsProvider(tastingId)).value ?? const [];
    final people = ref.watch(participantsProvider(tastingId)).value ??
        const <({Profile profile, bool isHost})>[];

    if (tasting == null) {
      return Scaffold(
        backgroundColor: c.paper,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    final me = ref.watch(currentUserIdProvider);
    final scale = tasting.config.scale;
    final revealed = items.where((i) => i.isRevealed).toList();

    final ranked = _rankGlasses(revealed, ratings, me);
    final leaderboard = _leaderboard(ratings, people);

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        const BackLink('← Afsløring'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stillingen', style: GlasType.display(28, color: c.ink)),
            const SizedBox(height: 5),
            Text('Efter ${revealed.length} af ${items.length} glas',
                style: GlasType.body(13, color: c.muted)),
          ],
        ),

        if (ranked.isEmpty)
          Text(
            'Der er ikke afsløret nogen glas endnu.',
            style: GlasType.body(14, color: c.muted),
          )
        else
          Column(
            children: [
              for (var i = 0; i < ranked.length; i++) ...[
                _GlassResult(
                  rank: i + 1,
                  result: ranked[i],
                  scale: scale,
                  best: ranked.first.groupAverage,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),

        if (tasting.config.guessOn && leaderboard.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Gættekonkurrencen'),
              const SizedBox(height: 10),
              GlasList(
                children: [
                  for (var i = 0; i < leaderboard.length; i++)
                    _LeaderRow(
                      rank: i + 1,
                      name: leaderboard[i].name,
                      points: leaderboard[i].points,
                      isMe: leaderboard[i].userId == me,
                    ),
                ],
              ),
            ],
          ),

        GlasButton(
          label: 'Tilbage',
          onTap: () => context.pop(),
        ),
      ],
    );
  }

  /// Glasses sorted by what the room gave them, with your own score alongside
  /// and how far apart the room was.
  static List<_GlassScore> _rankGlasses(
    List<TastingItem> items,
    List<Rating> ratings,
    String? me,
  ) {
    final results = <_GlassScore>[];

    for (final item in items) {
      final forItem = ratings
          .where((r) => r.tastingItemId == item.id && r.score != null)
          .toList();
      if (forItem.isEmpty) continue;

      final scores = forItem.map((r) => r.score!).toList();
      final average = scores.reduce((a, b) => a + b) / scores.length;

      results.add(_GlassScore(
        item: item,
        groupAverage: average,
        mine: forItem.where((r) => r.userId == me).firstOrNull?.score,
        spread: scores.length < 2
            ? 0
            : scores.reduce((a, b) => a > b ? a : b) -
                scores.reduce((a, b) => a < b ? a : b),
      ));
    }

    results.sort((a, b) => b.groupAverage.compareTo(a.groupAverage));
    return results;
  }

  static List<({String userId, String name, int points})> _leaderboard(
    List<Rating> ratings,
    List<({Profile profile, bool isHost})> people,
  ) {
    final names = {for (final p in people) p.profile.id: p.profile.firstName};
    final totals = <String, int>{};

    for (final rating in ratings) {
      totals[rating.userId] =
          (totals[rating.userId] ?? 0) + (rating.pointsTotal ?? 0);
    }

    final rows = totals.entries
        .map((e) => (
              userId: e.key,
              name: names[e.key] ?? 'Gæst',
              points: e.value,
            ))
        .toList()
      ..sort((a, b) => b.points.compareTo(a.points));
    return rows;
  }
}

class _GlassScore {
  const _GlassScore({
    required this.item,
    required this.groupAverage,
    required this.mine,
    required this.spread,
  });

  final TastingItem item;
  final double groupAverage;
  final double? mine;
  final double spread;
}

class _GlassResult extends StatelessWidget {
  const _GlassResult({
    required this.rank,
    required this.result,
    required this.scale,
    required this.best,
  });

  final int rank;
  final _GlassScore result;
  final RatingScale scale;
  final double best;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 18,
                child:
                    Text('$rank', style: GlasType.display(16, color: c.muted)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Glas ${result.item.position}',
                        style: GlasType.body(15, color: c.ink)),
                    const SizedBox(height: 2),
                    Text('afsløret · ${result.item.displayName}',
                        style: GlasType.body(12.5, color: c.muted)),
                  ],
                ),
              ),
              Text(scale.format(result.groupAverage),
                  style: GlasType.display(22, color: c.ink)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 6,
              color: c.accentSoft,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor:
                    best == 0 ? 0 : (result.groupAverage / best).clamp(0.0, 1.0),
                child: Container(color: c.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                result.mine == null
                    ? 'Du bedømte ikke'
                    : 'Din karakter ${scale.format(result.mine!)}',
                style: GlasType.body(12, color: c.muted),
              ),
              Text('Spredning ${scale.format(result.spread)}',
                  style: GlasType.body(12, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.name,
    required this.points,
    required this.isMe,
  });

  final int rank;
  final String name;
  final int points;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Container(
      color: isMe ? c.accentSoft : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text('$rank', style: GlasType.display(15, color: c.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: GlasType.body(14.5, color: c.ink)),
          ),
          Text('$points', style: GlasType.display(18, color: c.ink)),
          const SizedBox(width: 4),
          Text('point', style: GlasType.body(12, color: c.muted)),
        ],
      ),
    );
  }
}
