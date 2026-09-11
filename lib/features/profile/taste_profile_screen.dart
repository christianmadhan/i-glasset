import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/repositories/tasting_repository.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/glas_widgets.dart';
import '../live/bottle_thumbnail.dart';
import 'taste_profile.dart';

/// "Smagsprofil" — the patterns in someone's own ratings, and the best match
/// the archive can offer for what they'd like next.
class TasteProfileScreen extends ConsumerWidget {
  const TasteProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final archive = ref.watch(archiveProvider).value ?? const <ArchiveEntry>[];
    final taste = TasteProfile.from(archive);

    // The recommendation is the highest-scoring bottle the group has met that
    // this person didn't rate themselves — an honest suggestion rather than an
    // invented one.
    final me = ref.watch(currentUserIdProvider);
    final suggestion = (archive
            .where((e) =>
                e.rating.userId != me &&
                e.rating.score != null &&
                taste.highScoringGrapes.contains(e.item.grape))
            .toList()
          ..sort((a, b) => b.rating.score!.compareTo(a.rating.score!)))
        .firstOrNull;

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        const BackLink('← Profil'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              taste.isEmpty
                  ? 'Under opbygning'
                  : 'Bygget på ${taste.sampleSize} smagninger',
            ),
            const SizedBox(height: 6),
            Text('Din smagsprofil',
                style: GlasType.display(29, color: c.ink, height: 1.15)),
          ],
        ),

        NightPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(taste.summary,
                  style: GlasType.display(19, color: c.nightInk, height: 1.45)),
              if (taste.detail.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(taste.detail,
                    style:
                        GlasType.body(13, color: c.nightMuted, height: 1.5)),
              ],
            ],
          ),
        ),

        if (taste.traits.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Mønstre'),
              const SizedBox(height: 14),
              for (final trait in taste.traits) ...[
                MeterRow(
                  label: trait.label,
                  value: TasteProfile.frequencyLabel(trait.frequency),
                  fraction: trait.frequency,
                  height: 5,
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),

        if (suggestion != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Anbefalet til dig'),
              const SizedBox(height: 10),
              GlasCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BottleThumbnail(
                          item: suggestion.item,
                          width: 44,
                          height: 60,
                          radius: 8,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(suggestion.item.displayName,
                                  style: GlasType.body(15,
                                      color: c.ink, height: 1.25)),
                              const SizedBox(height: 3),
                              Text(suggestion.item.meta,
                                  style:
                                      GlasType.body(12.5, color: c.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: c.line, height: 1),
                    const SizedBox(height: 12),
                    Text('Derfor passer den til dig',
                        style: GlasType.body(12, color: c.muted)),
                    const SizedBox(height: 7),
                    for (final reason in _reasons(taste, suggestion)) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 7),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(reason,
                                style: GlasType.body(13.5,
                                    color: c.ink, height: 1.45)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                    ],
                  ],
                ),
              ),
            ],
          ),

        if (taste.isEmpty)
          Text(
            'Smagsprofilen bygger på dine egne karakterer og værtens noter. '
            'Den bliver skarpere for hver smagning, du er med til.',
            style: GlasType.body(13.5, color: c.muted, height: 1.5),
          ),
      ],
    );
  }

  static List<String> _reasons(TasteProfile taste, ArchiveEntry suggestion) {
    final item = suggestion.item;
    return [
      if (item.grape != null)
        '${item.grape} er blandt de druer, du giver højest',
      for (final trait in taste.traits.take(2))
        if (item.flavours.contains(trait.label) ||
            item.aromas.contains(trait.label))
          '${trait.label} — noget du ofte falder for',
      if (taste.averageScore != null && suggestion.rating.score != null)
        'Gruppen gav den ${suggestion.rating.score!.toStringAsFixed(1).replaceAll('.', ',')}',
    ];
  }
}
