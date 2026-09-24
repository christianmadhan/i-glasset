import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/vocabulary.dart';
import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../core/widgets/huce_mark.dart';
import '../../data/repositories/tasting_repository.dart';
import '../live/bottle_thumbnail.dart';

/// "Mine topsmagninger" — everything you've scored, best first.
class TopProductsScreen extends ConsumerWidget {
  const TopProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final archive = ref.watch(archiveProvider).value ?? const <ArchiveEntry>[];
    final top = ref.watch(topProductsProvider).value ?? const <ArchiveEntry>[];
    final filter = ref.watch(topProductsFilterProvider);

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      gap: 20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HuceLockup(),
            const SizedBox(height: 18),
            WholeWordsText('Mine topsmagninger',
                style: GlasType.display(29, color: c.ink)),
            const SizedBox(height: 5),
            Text(
              archive.isEmpty
                  ? 'Dit arkiv er tomt indtil videre'
                  : '${archive.length} produkter i dit arkiv',
              style: GlasType.body(13, color: c.muted),
            ),
          ],
        ),

        ChipWrap(
          children: [
            for (final option in Vocabulary.productFilters)
              GlasChip(
                label: option,
                selected: filter == option,
                onTap: () =>
                    ref.read(topProductsFilterProvider.notifier).set(option),
              ),
          ],
        ),

        if (top.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              archive.isEmpty
                  ? 'Når du har været med til din første smagning, samler vi '
                      'alt, du har smagt, her.'
                  : 'Ingen produkter i denne kategori.',
              style: GlasType.body(14, color: c.muted, height: 1.5),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < top.length; i++) ...[
                _TopRow(rank: i + 1, entry: top[i]),
                const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.rank, required this.entry});

  final int rank;
  final ArchiveEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final item = entry.item;

    return GlasCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => context.push('/items/${item.id}'),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text('$rank', style: GlasType.display(15, color: c.muted)),
          ),
          const SizedBox(width: 13),
          BottleThumbnail(item: item, width: 38, height: 52, radius: 8),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayName,
                    style: GlasType.body(14.5, color: c.ink, height: 1.25)),
                const SizedBox(height: 3),
                Text(
                  [
                    item.productType ?? entry.tasting.category,
                    if (item.region?.isNotEmpty == true) item.region!,
                    formatShortDate(
                        entry.tasting.finishedAt ?? entry.tasting.createdAt),
                  ].join(' · '),
                  style: GlasType.body(12, color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            entry.tasting.scale.format(entry.rating.score!),
            style: GlasType.display(20, color: c.accent),
          ),
        ],
      ),
    );
  }
}
