import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/models/rating.dart';
import '../../data/models/tasting_item.dart';
import 'media_sync_controller.dart';

/// "Opsummering" — the evening, closed off.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.tastingId});

  final String tastingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final tasting = ref.watch(tastingProvider(tastingId)).value;
    final items = ref.watch(itemsProvider(tastingId)).value ?? const [];
    final ratings = ref.watch(ratingsProvider(tastingId)).value ?? const [];
    final people = ref.watch(participantsProvider(tastingId)).value ??
        const <({Profile profile, bool isHost})>[];

    // Last chance to pick up any photo this device hasn't got yet — after this
    // the cloud copies are expendable.
    ref.watch(mediaSyncProvider(tastingId));

    if (tasting == null) {
      return Scaffold(
        backgroundColor: c.paper,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    final me = ref.watch(currentUserIdProvider);
    final scale = tasting.config.scale;
    final ranked = _rank(items, ratings);

    final myScores = ratings
        .where((r) => r.userId == me && r.score != null)
        .map((r) => r.score!)
        .toList();
    final allScores =
        ratings.where((r) => r.score != null).map((r) => r.score!).toList();

    final mostDivisive = ranked.isEmpty
        ? null
        : (ranked.toList()..sort((a, b) => b.spread.compareTo(a.spread))).first;

    final guessWinner = _guessWinner(ratings, people);

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      gap: 24,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Smagningen er slut'),
            const SizedBox(height: 6),
            Text(tasting.title,
                style: GlasType.display(29, color: c.ink, height: 1.15)),
            const SizedBox(height: 6),
            Text(
              [
                formatDate(tasting.finishedAt ?? DateTime.now()),
                '${people.length} deltagere',
                '${items.length} glas',
              ].join(' · '),
              style: GlasType.body(13.5, color: c.muted),
            ),
          ],
        ),

        if (ranked.isNotEmpty)
          NightPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aftenens vinder',
                    style: GlasType.body(12.5, color: c.nightMuted)),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ranked.first.item.displayName,
                              style: GlasType.display(24,
                                  color: c.nightInk, height: 1.15)),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (ranked.first.item.producer?.isNotEmpty == true)
                                ranked.first.item.producer!,
                              if (ranked.first.item.price != null)
                                ranked.first.item.formattedPrice,
                            ].join(' · '),
                            style: GlasType.body(12.5, color: c.nightMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(scale.format(ranked.first.average),
                        style: GlasType.display(38,
                            color: c.accent, height: 0.9)),
                  ],
                ),
              ],
            ),
          ),

        if (ranked.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Rangering'),
              const SizedBox(height: 8),
              GlasList(
                children: [
                  for (var i = 0; i < ranked.length; i++)
                    GlasTap(
                      onTap: () =>
                          context.push('/items/${ranked[i].item.id}'),
                      radius: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              child: Text('${i + 1}',
                                  style:
                                      GlasType.display(15, color: c.muted)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ranked[i].item.displayName,
                                      style:
                                          GlasType.body(14.5, color: c.ink)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'glas ${ranked[i].item.position}'
                                    '${ranked[i].item.region?.isNotEmpty == true ? ' · ${ranked[i].item.region}' : ''}',
                                    style:
                                        GlasType.body(12, color: c.muted),
                                  ),
                                ],
                              ),
                            ),
                            Text(scale.format(ranked[i].average),
                                style: GlasType.display(18, color: c.ink)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.1,
          children: [
            StatTile(
              value: allScores.isEmpty
                  ? '—'
                  : scale.format(
                      allScores.reduce((a, b) => a + b) / allScores.length),
              label: 'gruppens gennemsnit',
              valueSize: 20,
            ),
            StatTile(
              value: myScores.isEmpty
                  ? '—'
                  : scale.format(
                      myScores.reduce((a, b) => a + b) / myScores.length),
              label: 'dit gennemsnit',
              valueSize: 20,
            ),
            StatTile(
              value: mostDivisive?.item.displayName ?? '—',
              label: mostDivisive == null
                  ? 'mest uenighed'
                  : 'mest uenighed · ${scale.format(mostDivisive.spread)} i spredning',
              valueSize: 20,
            ),
            StatTile(
              value: guessWinner == null
                  ? '—'
                  : '${guessWinner.name} · ${guessWinner.points} pt',
              label: 'vinder af gættekonkurrencen',
              valueSize: 20,
            ),
          ],
        ),

        GlasButton(
          label: 'Gem i historikken',
          onTap: () => context.go('/'),
        ),
      ],
    );
  }

  static List<({TastingItem item, double average, double spread})> _rank(
    List<TastingItem> items,
    List<Rating> ratings,
  ) {
    final rows = <({TastingItem item, double average, double spread})>[];

    for (final item in items) {
      final scores = ratings
          .where((r) => r.tastingItemId == item.id && r.score != null)
          .map((r) => r.score!)
          .toList();
      if (scores.isEmpty) continue;

      rows.add((
        item: item,
        average: scores.reduce((a, b) => a + b) / scores.length,
        spread: scores.length < 2
            ? 0
            : scores.reduce((a, b) => a > b ? a : b) -
                scores.reduce((a, b) => a < b ? a : b),
      ));
    }

    rows.sort((a, b) => b.average.compareTo(a.average));
    return rows;
  }

  static ({String name, int points})? _guessWinner(
    List<Rating> ratings,
    List<({Profile profile, bool isHost})> people,
  ) {
    final names = {for (final p in people) p.profile.id: p.profile.firstName};
    final totals = <String, int>{};
    for (final rating in ratings) {
      totals[rating.userId] =
          (totals[rating.userId] ?? 0) + (rating.pointsTotal ?? 0);
    }
    if (totals.isEmpty) return null;

    final best = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (best.value == 0) return null;
    return (name: names[best.key] ?? 'Gæst', points: best.value);
  }
}
