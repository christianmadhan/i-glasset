import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/group.dart';
import '../../data/models/tasting.dart';
import '../../data/repositories/group_stats.dart';

/// "Gruppe" — the club's home: next tasting, history, standings, and the
/// numbers the group has accumulated.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final group = ref.watch(groupProvider(groupId));

    return group.when(
      loading: () => Scaffold(
        backgroundColor: c.paper,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: c.paper,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Gruppen kunne ikke hentes.',
                style: GlasType.body(15, color: c.muted)),
          ),
        ),
      ),
      data: (group) => _Loaded(group: group),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final members = ref.watch(groupMembersProvider(group.id)).value ??
        const <GroupMember>[];
    final history =
        ref.watch(groupHistoryProvider(group.id)).value ?? const <Tasting>[];
    final stats =
        ref.watch(groupStatsProvider(group.id)).value ?? GroupStats.empty;
    final upcoming = ref
        .watch(myTastingsProvider)
        .value
        ?.where((t) => t.groupId == group.id && t.status.isOpen)
        .toList();
    final next = (upcoming == null || upcoming.isEmpty) ? null : upcoming.first;

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
      gap: 24,
      children: [
        const BackLink('← Hjem'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WholeWordsText(group.name,
                style: GlasType.display(30, color: c.ink, height: 1.12)),
            const SizedBox(height: 6),
            Text(
              '${group.memberCount} ${group.memberCount == 1 ? 'medlem' : 'medlemmer'}'
              ' · oprettet ${group.createdAt.year}',
              style: GlasType.body(13.5, color: c.muted),
            ),
          ],
        ),

        if (members.isNotEmpty) _MemberStack(members: members),

        if (group.canHost)
          GlasButton(
            label: 'Opret smagning i gruppen',
            height: 50,
            onTap: () => context.push('/tastings/new?group=${group.id}'),
          ),

        if (next != null) _NextInGroup(tasting: next),

        if (history.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Tidligere smagninger'),
              const SizedBox(height: 10),
              GlasList(
                children: [
                  for (final tasting in history)
                    _HistoryTile(tasting: tasting),
                ],
              ),
            ],
          ),

        if (stats.leaderboard.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Stilling i klubben'),
              const SizedBox(height: 10),
              Text(
                'Gættepoint samlet over ${stats.tastingCount} '
                '${stats.tastingCount == 1 ? 'smagning' : 'smagninger'}',
                style: GlasType.body(12.5, color: c.muted),
              ),
              const SizedBox(height: 10),
              GlasList(
                children: [
                  for (var i = 0; i < stats.leaderboard.length; i++)
                    _LeaderTile(
                      rank: i + 1,
                      entry: stats.leaderboard[i],
                      isMe: stats.leaderboard[i].userId ==
                          ref.watch(currentUserIdProvider),
                    ),
                ],
              ),
            ],
          ),

        if (stats.spendByEvening.isNotEmpty) _SpendCard(stats: stats),

        if (stats.priceAccuracy.isNotEmpty) _PriceAccuracyCard(stats: stats),

        if (stats.records.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Rekorder'),
              const SizedBox(height: 8),
              GlasList(
                children: [
                  for (final record in stats.records)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(record.value,
                              style: GlasType.display(17, color: c.ink)),
                          const SizedBox(height: 3),
                          Text(record.label,
                              style: GlasType.body(12.5, color: c.muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

        if (!stats.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Klubbens tal'),
              const SizedBox(height: 10),
              // Rows rather than a fixed-ratio grid, so a tile grows when a
              // host's name or a large text size needs another line.
              StatRow(children: [
                StatTile(
                    value: '${stats.tastingCount}',
                    label: 'smagninger afholdt'),
                StatTile(
                    value: '${stats.productCount}', label: 'produkter smagt'),
              ]),
              const SizedBox(height: 10),
              StatRow(children: [
                StatTile(
                  value: stats.average == null
                      ? '—'
                      : formatScore(stats.average!),
                  label: 'gennemsnit i klubben',
                ),
                StatTile(
                    value: stats.mostActiveHost ?? '—',
                    label: 'mest aktive vært'),
              ]),
            ],
          ),

        if (stats.isEmpty && history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Når I har holdt jeres første smagning, samles stillingen, '
              'forbruget og rekorderne her.',
              style: GlasType.body(13.5, color: c.muted, height: 1.5),
            ),
          ),
      ],
    );
  }
}

/// The overlapping row of member monograms.
class _MemberStack extends StatelessWidget {
  const _MemberStack({required this.members});

  final List<GroupMember> members;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final shown = members.where((m) => !m.pending).take(8).toList();

    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 26,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.paper, width: 2),
                ),
                child: Monogram(
                  shown[i].profile.initials,
                  size: 30,
                  radius: 999,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NextInGroup extends ConsumerWidget {
  const _NextInGroup({required this.tasting});

  final Tasting tasting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final isHost = tasting.isHostedBy(ref.watch(currentUserIdProvider));

    return GlasCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Næste smagning'),
          const SizedBox(height: 14),
          Text(tasting.title, style: GlasType.display(22, color: c.ink)),
          const SizedBox(height: 4),
          Text(
            [
              formatWhen(tasting.scheduledFor),
              if (tasting.hostName != null) 'vært ${tasting.hostName}',
              if (tasting.itemCount > 0) '${tasting.itemCount} glas',
            ].join(' · '),
            style: GlasType.body(13.5, color: c.muted),
          ),
          const SizedBox(height: 14),
          Divider(color: c.line, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tilmeldingskode',
                        style: GlasType.body(12, color: c.muted)),
                    const SizedBox(height: 3),
                    Text(tasting.joinCode,
                        style: GlasType.mono(22, color: c.ink, tracking: 0.14)),
                  ],
                ),
              ),
              GlasTap(
                onTap: () async {
                  await Clipboard.setData(
                      ClipboardData(text: tasting.joinCode));
                  if (context.mounted) {
                    showGlasMessage(context, 'Koden er kopieret.');
                  }
                },
                radius: 999,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.line),
                  ),
                  child: Text('Kopiér',
                      style: GlasType.body(12.5, color: c.muted)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ButtonRow(
            gap: 8,
            minChildWidth: 110,
            children: [
              GlasButton(
                label: isHost ? 'Se program' : 'Se detaljer',
                height: 44,
                tone: GlasButtonTone.outline,
                onTap: () => context.push('/tastings/${tasting.id}/program'),
              ),
              GlasButton(
                label: 'Deltag',
                height: 44,
                onTap: () => context.push('/join?code=${tasting.joinCode}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.tasting});

  final Tasting tasting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    return GlasTap(
      onTap: () => context.push('/tastings/${tasting.id}/archive'),
      radius: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tasting.title, style: GlasType.body(15, color: c.ink)),
                  const SizedBox(height: 2),
                  Text(formatDate(tasting.finishedAt),
                      style: GlasType.body(12.5, color: c.muted)),
                ],
              ),
            ),
            Text('›', style: GlasType.body(15, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

class _LeaderTile extends StatelessWidget {
  const _LeaderTile({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  final int rank;
  final LeaderboardEntry entry;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: GlasType.body(14.5, color: c.ink)),
                const SizedBox(height: 2),
                Text(entry.meta, style: GlasType.body(12, color: c.muted)),
              ],
            ),
          ),
          Text('${entry.points}', style: GlasType.display(19, color: c.ink)),
          const SizedBox(width: 4),
          Text('pt', style: GlasType.body(12, color: c.muted)),
        ],
      ),
    );
  }
}

class _SpendCard extends StatelessWidget {
  const _SpendCard({required this.stats});

  final GroupStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final top = stats.spendByEvening.first.amount;

    return GlasCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Klubben har brugt'),
          const SizedBox(height: 4),
          Text(formatMoney(stats.spendTotal),
              style: GlasType.display(30, color: c.ink, height: 1.1)),
          const SizedBox(height: 4),
          Text(
            '${stats.bottleCount} flasker · '
            '${formatMoney(stats.averageBottlePrice)} i snit pr. flaske',
            style: GlasType.body(12.5, color: c.muted),
          ),
          const SizedBox(height: 14),
          Divider(color: c.line, height: 1),
          const SizedBox(height: 14),
          Text('Forbrug pr. aften', style: GlasType.body(12.5, color: c.muted)),
          const SizedBox(height: 11),
          for (final evening in stats.spendByEvening.take(6)) ...[
            MeterRow(
              label: evening.name,
              value: formatMoney(evening.amount),
              fraction: top == 0 ? 0 : evening.amount / top,
            ),
            const SizedBox(height: 11),
          ],
        ],
      ),
    );
  }
}

class _PriceAccuracyCard extends StatelessWidget {
  const _PriceAccuracyCard({required this.stats});

  final GroupStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    // Closest guess gets the fullest bar, so the meter reads as "better".
    final worst = stats.priceAccuracy.last.distance;

    return GlasCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Bedst til at gætte prisen'),
          const SizedBox(height: 4),
          Text('Gennemsnitlig afstand fra butiksprisen',
              style: GlasType.body(12.5, color: c.muted)),
          const SizedBox(height: 14),
          for (final person in stats.priceAccuracy.take(6)) ...[
            MeterRow(
              label: person.name,
              value: '${formatMoney(person.distance)} fra',
              fraction: worst == 0 ? 1 : 1 - (person.distance / (worst * 1.1)),
            ),
            const SizedBox(height: 11),
          ],
        ],
      ),
    );
  }
}
