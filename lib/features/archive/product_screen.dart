import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/glas_widgets.dart';
import '../live/bottle_thumbnail.dart';

/// "Produkt" — one bottle, as you met it: your score, the room's, the facts,
/// and what you wrote at the time.
class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final archive = ref.watch(archiveProvider);

    final entry =
        archive.value?.where((e) => e.item.id == itemId).firstOrNull;

    if (entry == null) {
      return Scaffold(
        backgroundColor: c.paper,
        body: Center(
          child: archive.isLoading
              ? CircularProgressIndicator(color: c.accent)
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Produktet er ikke i dit arkiv.',
                    style: GlasType.body(15, color: c.muted),
                  ),
                ),
        ),
      );
    }

    final item = entry.item;
    final scale = entry.tasting.scale;
    final ratings =
        ref.watch(ratingsProvider(entry.tasting.id)).value ?? const [];
    final groupScores = ratings
        .where((r) => r.tastingItemId == itemId && r.score != null)
        .map((r) => r.score!)
        .toList();
    final groupAverage = groupScores.isEmpty
        ? null
        : groupScores.reduce((a, b) => a + b) / groupScores.length;

    // Have they met this bottle before? Matched by name, which is as good as
    // it gets without a shared product catalogue.
    final timesTasted = (archive.value ?? [])
        .where((e) =>
            e.item.name != null &&
            e.item.name!.toLowerCase() == item.name?.toLowerCase())
        .length;

    final facts = <({String label, String value})>[
      if (item.productType?.isNotEmpty == true)
        (label: 'Type', value: item.productType!),
      if (item.grape?.isNotEmpty == true) (label: 'Drue', value: item.grape!),
      if (item.region?.isNotEmpty == true || item.country?.isNotEmpty == true)
        (
          label: 'Region',
          value: [item.region, item.country]
              .where((v) => v?.isNotEmpty == true)
              .join(', ')
        ),
      if (item.vintage != null) (label: 'Årgang', value: '${item.vintage}'),
      if (item.abv != null) (label: 'Alkohol', value: item.formattedAbv),
      if (item.price != null) (label: 'Pris', value: item.formattedPrice),
      if (item.extra?.isNotEmpty == true)
        (label: 'Særligt', value: item.extra!),
      (
        label: 'Smagt',
        value: 'Glas ${item.position}, ${entry.tasting.title}'
      ),
    ];

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        const BackLink('← Tilbage'),

        BottleThumbnail(
          item: item,
          height: 210,
          radius: 20,
          caption: 'flaskefoto',
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.producer?.isNotEmpty == true) ...[
              Text(item.producer!, style: GlasType.body(13, color: c.muted)),
              const SizedBox(height: 6),
            ],
            Text(item.displayName,
                style: GlasType.display(28, color: c.ink, height: 1.15)),
          ],
        ),

        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: StatTile(
                value: entry.rating.score == null
                    ? '—'
                    : scale.format(entry.rating.score!),
                label: 'Din karakter',
                valueSize: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                value:
                    groupAverage == null ? '—' : scale.format(groupAverage),
                label: 'Gruppen',
                valueSize: 24,
              ),
            ),
          ],
        ),

        GlasList(
          children: [
            for (final fact in facts)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(fact.label,
                          style: GlasType.body(13, color: c.muted)),
                    ),
                    Expanded(
                      child: Text(fact.value,
                          style: GlasType.body(14, color: c.ink)),
                    ),
                  ],
                ),
              ),
          ],
        ),

        if (entry.rating.notes?.trim().isNotEmpty == true)
          GlasCard(
            radius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dine noter · '
                  '${formatDate(entry.tasting.finishedAt ?? entry.tasting.createdAt)}',
                  style: GlasType.body(12, color: c.muted),
                ),
                const SizedBox(height: 8),
                Text('“${entry.rating.notes!.trim()}”',
                    style: GlasType.displayItalic(16, color: c.ink)),
              ],
            ),
          ),

        GlasButton(
          label: timesTasted > 1
              ? 'Smagt $timesTasted gange · se historik'
              : 'Se aftenen',
          tone: GlasButtonTone.outline,
          height: 48,
          onTap: () =>
              context.push('/tastings/${entry.tasting.id}/archive'),
        ),
      ],
    );
  }
}
