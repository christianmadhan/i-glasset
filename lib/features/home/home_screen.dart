import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../core/widgets/huce_mark.dart';
import '../../data/models/group.dart';
import '../../data/models/tasting.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final profile = ref.watch(myProfileProvider).value;
    final next = ref.watch(nextTastingProvider).value;
    final groups = ref.watch(myGroupsProvider).value ?? const <Group>[];
    final recent = ref.watch(recentTastingsProvider).value ?? const <Tasting>[];
    final stats = ref.watch(profileStatsProvider).value;
    final archive = ref.watch(archiveProvider).value;

    return RefreshIndicator(
      color: c.accent,
      backgroundColor: c.card,
      onRefresh: () async {
        ref.invalidate(myTastingsProvider);
        ref.invalidate(myGroupsProvider);
        ref.invalidate(archiveProvider);
      },
      child: PaperScreen(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        gap: 26,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HuceLockup(),
              const SizedBox(height: 18),
              WholeWordsText(
                greeting(profile?.firstName),
                style: GlasType.display(30, color: c.ink),
              ),
            ],
          ),

          if (next != null)
            _NextTastingCard(tasting: next)
          else
            const _NothingPlannedCard(),

          if (stats != null && stats.products > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Dine tal'),
                const SizedBox(height: 10),
                StatRow(
                  children: [
                    StatTile(
                      value: stats.average == null
                          ? '—'
                          : formatScore(stats.average!),
                      label: 'Gennemsnit i år',
                      valueSize: 32,
                    ),
                    StatTile(
                      value: mostTastedLabel(archive) ?? '—',
                      label: 'Mest smagt',
                      valueSize: 20,
                    ),
                  ],
                ),
              ],
            ),

          if (groups.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  'Dine grupper',
                  trailing: GlasTap(
                    onTap: () => context.go('/?tab=1'),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text('Se alle',
                          style: GlasType.body(12.5, color: c.accent)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                for (final group in groups.take(3)) ...[
                  GroupRow(group: group),
                  const SizedBox(height: 8),
                ],
              ],
            ),

          if (recent.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Seneste smagninger'),
                const SizedBox(height: 10),
                for (final tasting in recent) ...[
                  _HistoryRow(tasting: tasting),
                  const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// The dark card at the top of Hjem: what's next, and the way in.
class _NextTastingCard extends ConsumerWidget {
  const _NextTastingCard({required this.tasting});

  final Tasting tasting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final isHost = tasting.isHostedBy(ref.watch(currentUserIdProvider));

    return NightPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('Næste smagning', color: c.nightMuted),
          const SizedBox(height: 6),
          WholeWordsText(tasting.title,
              style: GlasType.display(25, color: c.nightInk, height: 1.2)),
          const SizedBox(height: 6),
          Text(
            [
              if (tasting.groupName != null) tasting.groupName!,
              formatWhen(tasting.scheduledFor),
              if (tasting.hostName != null) 'vært ${tasting.hostName}',
            ].where((s) => s.isNotEmpty).join(' · '),
            style: GlasType.body(13.5, color: c.nightMuted),
          ),
          const SizedBox(height: 18),
          GlasTap(
            onTap: () => context.push(
              isHost ? '/tastings/${tasting.id}/program' : '/join',
            ),
            radius: 14,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: c.nightInk,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isHost ? 'Åbn dit program' : 'Deltag med kode',
                      style: GlasType.body(15.5,
                          color: c.night, weight: FontWeight.w500),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tasting.joinCode,
                      style: GlasType.mono(13,
                          color: c.night.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NothingPlannedCard extends StatelessWidget {
  const _NothingPlannedCard();

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return NightPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('Ingen smagning planlagt', color: c.nightMuted),
          const SizedBox(height: 6),
          Text('Skal vi åbne en flaske?',
              style: GlasType.display(25, color: c.nightInk, height: 1.2)),
          const SizedBox(height: 18),
          ButtonRow(
            minChildWidth: 140,
            children: [
              GlasTap(
                  onTap: () => context.push('/join'),
                  radius: 14,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.nightInk,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: FitText('Deltag med kode',
                        style: GlasType.body(15, color: c.night)),
                  ),
                ),
              GlasTap(
                  onTap: () => context.push('/tastings/new'),
                  radius: 14,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.nightLine),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: FitText('Opret smagning',
                        style: GlasType.body(15, color: c.nightInk)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A group in a list: monogram, name, "12 medlemmer · 38 smagninger".
class GroupRow extends StatelessWidget {
  const GroupRow({super.key, required this.group, this.trailing});

  final Group group;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => context.push('/groups/${group.id}'),
      child: Row(
        children: [
          Monogram(group.initials),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: GlasType.body(15, color: c.ink)),
                const SizedBox(height: 2),
                Text(group.meta, style: GlasType.body(12.5, color: c.muted)),
              ],
            ),
          ),
          if (trailing != null) trailing! else
            Text('›', style: GlasType.body(15, color: c.muted)),
        ],
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.tasting});

  final Tasting tasting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final archive = ref.watch(archiveProvider).value;
    final mine = archive
            ?.where((e) => e.tasting.id == tasting.id && e.rating.score != null)
            .toList() ??
        const [];
    final average = mine.isEmpty
        ? null
        : mine.fold<double>(0, (sum, e) => sum + e.rating.score!) / mine.length;

    return GlasCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => context.push('/tastings/${tasting.id}/archive'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tasting.title,
                    style: GlasType.display(17, color: c.ink)),
                const SizedBox(height: 3),
                Text(
                  [
                    formatDate(tasting.finishedAt ?? tasting.createdAt),
                    if (tasting.groupName != null) tasting.groupName!,
                  ].join(' · '),
                  style: GlasType.body(12.5, color: c.muted),
                ),
              ],
            ),
          ),
          if (average != null)
            Text(
              tasting.scale.format(average),
              style: GlasType.display(19, color: c.accent),
            ),
        ],
      ),
    );
  }
}
