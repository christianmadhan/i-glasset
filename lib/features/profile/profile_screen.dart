import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/repositories/group_repository.dart';
import 'taste_profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final profile = ref.watch(myProfileProvider).value;
    final stats = ref.watch(profileStatsProvider).value ?? ProfileStats.empty;
    final archive = ref.watch(archiveProvider).value ?? const [];
    final taste = TasteProfile.from(archive);

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      children: [
        Row(
          children: [
            Monogram(
              profile?.initials ?? '?',
              size: 66,
              radius: 999,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile?.displayName ?? 'Gæst',
                      style: GlasType.display(24, color: c.ink)),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (stats.memberSince != null)
                        'Medlem siden ${stats.memberSince!.year}',
                      '${stats.groups} ${stats.groups == 1 ? 'gruppe' : 'grupper'}',
                    ].join(' · '),
                    style: GlasType.body(13, color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),

        StatRow(
          gap: 8,
          children: [
            StatTile(value: '${stats.products}', label: 'produkter'),
            StatTile(value: '${stats.tastings}', label: 'smagninger'),
            StatTile(
              value: stats.average == null ? '—' : formatScore(stats.average!),
              label: 'gennemsnit',
            ),
          ],
        ),

        NightPanel(
          padding: const EdgeInsets.all(18),
          radius: 18,
          onTap: () => context.push('/taste'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Din smagsprofil',
                        style: GlasType.display(19, color: c.nightInk)),
                    const SizedBox(height: 5),
                    Text(
                      taste.isEmpty
                          ? 'Bygges når du har smagt lidt flere'
                          : taste.headlineTraits,
                      style: GlasType.body(12.5, color: c.nightMuted),
                    ),
                  ],
                ),
              ),
              Text('›', style: GlasType.body(18, color: c.nightMuted)),
            ],
          ),
        ),

        GlasList(
          children: [
            _Row(
              label: 'Mine topprodukter',
              detail: '${stats.products}',
              onTap: () => context.go('/?tab=2'),
            ),
            _Row(
              label: 'Mine grupper',
              detail: '${stats.groups}',
              onTap: () => context.go('/?tab=1'),
            ),
            _Row(
              label: 'Kom godt i gang',
              detail: '4 trin',
              onTap: () => context.push('/guide'),
            ),
            _ThemeRow(),
            _Row(
              label: 'Billeder på enheden',
              detail: '',
              onTap: () => context.push('/storage'),
            ),
            _Row(
              label: 'Log ud',
              detail: '',
              onTap: () async {
                final confirmed = await showGlasConfirm(
                  context,
                  title: 'Log ud?',
                  body: 'Dine billeder bliver på enheden.',
                  confirmLabel: 'Log ud',
                );
                if (!confirmed || !context.mounted) return;
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),

        GlasButton(
          label: 'Opret smagning',
          height: 50,
          tone: GlasButtonTone.outline,
          onTap: () => context.push('/tastings/new'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.detail, this.onTap});

  final String label;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasTap(
      onTap: onTap,
      radius: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: GlasType.body(14.5, color: c.ink)),
            ),
            if (detail.isNotEmpty)
              Text(detail, style: GlasType.body(13, color: c.muted)),
            const SizedBox(width: 12),
            Text('›', style: GlasType.body(15, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

/// The design ships three visual directions; this is where they're switched.
class _ThemeRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final current = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Udseende', style: GlasType.body(14.5, color: c.ink)),
          const SizedBox(height: 11),
          ChipWrap(
            spacing: 6,
            children: [
              for (final theme in GlasThemeName.values)
                GlasChip(
                  label: theme.label,
                  dense: true,
                  selected: current == theme,
                  onTap: () => ref.read(themeProvider.notifier).set(theme),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
