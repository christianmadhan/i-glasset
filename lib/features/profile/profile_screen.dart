import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../core/widgets/huce_mark.dart';
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
        const HuceLockup(),
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
                  WholeWordsText(profile?.displayName ?? 'Gæst',
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
              label: 'Rapportér indhold',
              detail: '',
              onTap: () => _reportContent(context),
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
            if (Env.isLocal)
              _Row(
                label: 'Slet alle mine data',
                detail: '',
                onTap: () => _eraseEverything(context, ref),
              ),
          ],
        ),

        GlasButton(
          label: 'Opret smagning',
          height: 50,
          tone: GlasButtonTone.outline,
          onTap: () => context.push('/tastings/new'),
        ),

        const HuceFooter(),
      ],
    );
  }
}

/// "Rapportér indhold" — the way to tell us about a name, a note or a photo
/// another participant put in front of you. There is no server to file it
/// with, so it goes to a person, by mail.
Future<void> _reportContent(BuildContext context) async {
  final confirmed = await showGlasConfirm(
    context,
    title: 'Rapportér indhold',
    body: 'Har en deltager skrevet eller vist noget, der ikke hører hjemme i '
        'en smagning? Skriv til os med smagningens kode og hvad det drejer '
        'sig om, så følger vi op. Værten kan altid fjerne en deltager fra '
        'rummet — hold på navnet i lobbyen eller på listen over, hvem der '
        'har bedømt.',
    confirmLabel: 'Skriv til os',
  );
  if (!confirmed || !context.mounted) return;
  final mail = Uri.parse(
    'mailto:christian@huce.dk?subject='
    '${Uri.encodeComponent('I Glasset: rapportér indhold')}',
  );
  final opened = await launchUrl(mail);
  if (!opened && context.mounted) {
    showGlasMessage(context, 'Skriv til christian@huce.dk');
  }
}

/// "Slet alle mine data" — profile, groups, tastings, ratings and photos, gone
/// from this phone. What was already shared with the other phones in a room
/// stays on those phones, as it would around a table.
Future<void> _eraseEverything(BuildContext context, WidgetRef ref) async {
  final confirmed = await showGlasConfirm(
    context,
    title: 'Slet alle dine data?',
    body: 'Profil, grupper, smagninger, bedømmelser og flaskebilleder slettes '
        'fra denne telefon. Det kan ikke fortrydes.',
    confirmLabel: 'Slet alt',
  );
  if (!confirmed || !context.mounted) return;
  try {
    final repo = ref.read(localTastingRepositoryProvider);
    await repo.host.stop();
    await repo.guest.disconnect();
    await ref.read(localSessionProvider).forget();
    await ref.read(localStoreProvider).wipe();
    await ref.read(localMediaStoreProvider).wipe();
    if (context.mounted) context.go('/login');
  } on Object catch (error) {
    if (context.mounted) showGlasError(context, error);
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
