import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/models/tasting_config.dart';
import '../../data/models/tasting_item.dart';
import '../live/bottle_thumbnail.dart';
import '../live/media_sync_controller.dart';

/// "Tidligere smagning" — an evening, re-read. Photos come off the device, so
/// this screen works with no connection at all.
class PreviousTastingScreen extends ConsumerWidget {
  const PreviousTastingScreen({super.key, required this.tastingId});

  final String tastingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final tasting = ref.watch(tastingProvider(tastingId)).value;
    final items = ref.watch(itemsProvider(tastingId)).value ?? const [];
    final ratings = ref.watch(ratingsProvider(tastingId)).value ?? const [];
    final people = ref.watch(participantsProvider(tastingId)).value ??
        const <({Profile profile, bool isHost})>[];

    // Fills in anything this device missed on the night.
    ref.watch(mediaSyncProvider(tastingId));

    if (tasting == null) {
      return Scaffold(
        backgroundColor: c.paper,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    final me = ref.watch(currentUserIdProvider);
    final scale = tasting.config.scale;
    final revealed = items.where((i) => i.isRevealed).toList();

    final myNotes = ratings
        .where((r) => r.userId == me && (r.notes?.trim().isNotEmpty ?? false))
        .toList();

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        const BackLink('← Historik'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tasting.title,
                style: GlasType.display(28, color: c.ink, height: 1.15)),
            const SizedBox(height: 6),
            Text(
              [
                formatDate(tasting.finishedAt ?? tasting.createdAt),
                if (tasting.groupName != null) tasting.groupName!,
                '${people.length} deltagere',
                '${items.length} glas',
              ].join(' · '),
              style: GlasType.body(13.5, color: c.muted),
            ),
          ],
        ),

        ChipWrap(
          spacing: 8,
          children: [
            if (tasting.theme?.isNotEmpty == true)
              _Tag('Tema: ${tasting.theme}'),
            if (tasting.hostName != null) _Tag('Vært: ${tasting.hostName}'),
            _Tag(tasting.category),
          ],
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Glassene i rækkefølge'),
            const SizedBox(height: 10),
            for (final item in revealed) ...[
              _ArchiveRow(
                item: item,
                scale: scale,
                mine: ratings
                    .where((r) => r.tastingItemId == item.id && r.userId == me)
                    .firstOrNull
                    ?.score,
                group: () {
                  final scores = ratings
                      .where((r) =>
                          r.tastingItemId == item.id && r.score != null)
                      .map((r) => r.score!)
                      .toList();
                  return scores.isEmpty
                      ? null
                      : scores.reduce((a, b) => a + b) / scores.length;
                }(),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),

        for (final note in myNotes) ...[
          Builder(builder: (context) {
            final item =
                items.where((i) => i.id == note.tastingItemId).firstOrNull;
            return GlasCard(
              radius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dine noter, glas ${item?.position ?? '?'}',
                    style: GlasType.body(12, color: c.muted),
                  ),
                  const SizedBox(height: 8),
                  Text('“${note.notes!.trim()}”',
                      style: GlasType.displayItalic(16, color: c.ink)),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.line),
      ),
      child: Text(label, style: GlasType.body(12.5, color: c.muted)),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    required this.item,
    required this.scale,
    required this.mine,
    required this.group,
  });

  final TastingItem item;
  final RatingScale scale;
  final double? mine;
  final double? group;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/items/${item.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BottleThumbnail(item: item, width: 52, height: 70, radius: 9),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GLAS ${item.position}',
                    style: GlasType.label(11, color: c.muted, tracking: 0.1)),
                const SizedBox(height: 5),
                Text(item.displayName,
                    style: GlasType.body(15, color: c.ink, height: 1.25)),
                if (item.meta.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(item.meta,
                      style: GlasType.body(12.5, color: c.muted)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (mine != null) ...[
                      Text('Din ', style: GlasType.body(12.5, color: c.ink)),
                      Text(scale.format(mine!),
                          style: GlasType.display(15, color: c.ink)),
                      const SizedBox(width: 14),
                    ],
                    if (group != null) ...[
                      Text('Gruppen ',
                          style: GlasType.body(12.5, color: c.muted)),
                      Text(scale.format(group!),
                          style: GlasType.display(15, color: c.muted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
