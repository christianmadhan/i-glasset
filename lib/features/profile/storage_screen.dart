import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../live/media_sync_controller.dart';

final _storageUsageProvider = FutureProvider<({int bytes, String path})>(
  (ref) async {
    final store = ref.watch(localMediaStoreProvider);
    return (bytes: await store.usedBytes(), path: (await store.root()).path);
  },
);

/// Where the user can see — and take charge of — the images this app keeps on
/// their device. Nothing here talks to the database: these are their files.
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final usage = ref.watch(_storageUsageProvider).value;
    final tastings = ref.watch(myTastingsProvider).value ?? const [];

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        const BackLink('← Profil'),
        Text('Billeder på enheden',
            style: GlasType.display(29, color: c.ink, height: 1.15)),

        Text(
          'Flaskebillederne ligger i din egen mappe på telefonen. De hentes '
          'én gang, når værten afslører et glas, og bliver liggende — også '
          'når du er offline, og også hvis smagningen bliver slettet i skyen.',
          style: GlasType.body(13.5, color: c.muted, height: 1.55),
        ),

        GlasCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Plads brugt'),
              const SizedBox(height: 6),
              Text(
                usage == null ? '—' : _formatBytes(usage.bytes),
                style: GlasType.display(30, color: c.ink, height: 1.1),
              ),
              const SizedBox(height: 10),
              if (usage != null)
                Text(usage.path,
                    style: GlasType.mono(11, color: c.muted)),
            ],
          ),
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Hent igen'),
            const SizedBox(height: 10),
            Text(
              'Mangler et billede — fordi du var offline, da det blev '
              'afsløret — kan du hente det igen her.',
              style: GlasType.body(13, color: c.muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            for (final tasting in tastings.take(10)) ...[
              GlasCard(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                onTap: () async {
                  await ref
                      .read(mediaSyncProvider(tasting.id).notifier)
                      .resync();
                  ref.invalidate(_storageUsageProvider);
                  if (context.mounted) {
                    showGlasMessage(context, 'Billederne er hentet.');
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(tasting.title,
                          style: GlasType.body(15, color: c.ink)),
                    ),
                    Text('Hent', style: GlasType.body(13, color: c.accent)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
}
