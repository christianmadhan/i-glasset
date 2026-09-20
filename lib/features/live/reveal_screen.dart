import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/rating.dart';
import '../../data/models/tasting.dart';
import '../../data/models/tasting_config.dart';
import '../../data/models/tasting_item.dart';
import 'bottle_thumbnail.dart';
import 'media_sync_controller.dart';
import 'rating_controller.dart';
import 'tasting_exit.dart';

/// "Afsløring" — what was actually in the glass, how the room scored it, and
/// what your guess was worth.
///
/// This is also the moment the bottle photo arrives: opening this screen kicks
/// off the download into the device's own folder, and from then on the image is
/// read from disk.
class RevealScreen extends ConsumerStatefulWidget {
  const RevealScreen({super.key, required this.tastingId});

  final String tastingId;

  @override
  ConsumerState<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends ConsumerState<RevealScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.glas.onNight;

    final live = ref.watch(tastingStreamProvider(widget.tastingId)).value;
    final tasting = live ?? ref.watch(tastingProvider(widget.tastingId)).value;
    final items = ref.watch(itemsProvider(widget.tastingId)).value;

    if (tasting == null || items == null || items.isEmpty) {
      return Scaffold(
        backgroundColor: c.night,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    final position = tasting.currentPosition.clamp(1, items.length);
    final item = items.firstWhere(
      (i) => i.position == position,
      orElse: () => items.first,
    );

    // Pull this tasting's revealed photos onto the device. Idempotent, so
    // returning to the screen doesn't re-download anything.
    ref.watch(mediaSyncProvider(widget.tastingId));

    // The host moving on carries everyone with them.
    ref.listen(tastingStreamProvider(widget.tastingId), (_, next) {
      final value = next.value;
      if (!mounted || value == null) return;
      if (value.status == TastingStatus.finished) {
        context.pushReplacement('/tastings/${widget.tastingId}/summary');
      } else if (value.currentPosition > position) {
        context.pushReplacement('/tastings/${widget.tastingId}/live');
      }
    });

    final isHost = tasting.isHostedBy(ref.watch(currentUserIdProvider));
    final rating = ref.watch(ratingProvider(item.id)).value;
    final allRatings = ref.watch(ratingsProvider(widget.tastingId)).value ?? [];
    final groupScores = allRatings
        .where((r) => r.tastingItemId == item.id && r.score != null)
        .map((r) => r.score!)
        .toList();
    final groupAverage = groupScores.isEmpty
        ? null
        : groupScores.reduce((a, b) => a + b) / groupScores.length;

    final scale = tasting.config.scale;
    final isLast = position >= items.length;

    return NightScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
      gap: 20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BackLink(
                  '← Forlad',
                  color: c.nightMuted,
                  onTap: () => leaveTasting(context, ref, widget.tastingId),
                ),
                const SizedBox(width: 14),
                Text('Glas $position af ${items.length}',
                    style: GlasType.body(13, color: c.nightMuted)),
                const Spacer(),
                SectionLabel('Afsløret', color: c.accent),
              ],
            ),
            GuestConnectionNote(isHost: isHost),
          ],
        ),

        _RevealBody(item: item),

        StatRow(
          children: [
            _ScoreBox(
              value: groupAverage == null ? '—' : scale.format(groupAverage),
              label: 'Gruppen',
            ),
            _ScoreBox(
              value: rating?.score == null ? '—' : scale.format(rating!.score!),
              label: 'Din karakter',
              highlighted: true,
            ),
          ],
        ),

        if (tasting.config.guessOn && rating != null)
          _PointsCard(rating: rating, item: item, config: tasting.config),

        const SizedBox(height: 4),

        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlasButton(
              label: 'Se stillingen',
              tone: GlasButtonTone.outline,
              height: 48,
              onTap: () =>
                  context.push('/tastings/${widget.tastingId}/results'),
            ),
            const SizedBox(height: 10),
            if (isHost)
              GlasButton(
                label: isLast
                    ? 'Afslut smagningen'
                    : 'Videre til glas ${position + 1}',
                tone: GlasButtonTone.accent,
                enabled: !_busy,
                onTap: () => _advance(position, items.length),
              )
            else if (isLast)
              // Everything is on this phone already; nobody has to wait for
              // the host's tap to close the evening.
              GlasButton(
                label: 'Se opsummeringen',
                tone: GlasButtonTone.accent,
                onTap: () => context.pushReplacement(
                  '/tastings/${widget.tastingId}/summary',
                ),
              )
            else
              Center(
                child: Text(
                  'Værten går videre til glas ${position + 1}',
                  style: GlasType.body(13, color: c.nightMuted),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _advance(int position, int total) async {
    setState(() => _busy = true);
    final repo = ref.read(tastingRepositoryProvider);
    try {
      if (position >= total) {
        await repo.finish(widget.tastingId);
        ref.invalidate(myTastingsProvider);
        ref.invalidate(archiveProvider);
        if (mounted) {
          context.pushReplacement('/tastings/${widget.tastingId}/summary');
        }
      } else {
        await repo.advance(widget.tastingId, position + 1);
        ref.invalidate(tastingProvider(widget.tastingId));
        if (mounted) {
          context.pushReplacement('/tastings/${widget.tastingId}/live');
        }
      }
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The photo and the name, arriving together with a blur-to-sharp entrance.
class _RevealBody extends StatelessWidget {
  const _RevealBody({required this.item});

  final TastingItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: const Cubic(0.2, 0.7, 0.2, 1),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - t)),
          child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BottleThumbnail(
            item: item,
            height: 196,
            radius: 20,
            caption: 'flaskefoto',
            onNight: true,
          ),
          const SizedBox(height: 18),
          if (item.producer?.isNotEmpty == true) ...[
            Text(item.producer!,
                style: GlasType.body(13, color: c.nightMuted)),
            const SizedBox(height: 7),
          ],
          Text(item.displayName,
              style: GlasType.display(30, color: c.nightInk, height: 1.15)),
          if (item.meta.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(item.meta, style: GlasType.body(13.5, color: c.nightMuted)),
          ],
          if (item.extra?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: c.accentNightSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(item.extra!,
                  style: GlasType.body(12.5, color: c.nightInk)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.value,
    required this.label,
    this.highlighted = false,
  });

  final String value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return RiseIn(
      delay: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: highlighted ? c.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? c.accent
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: GlasType.display(28, color: c.nightInk, height: 1)),
            const SizedBox(height: 3),
            Text(label, style: GlasType.body(12, color: c.nightMuted)),
          ],
        ),
      ),
    );
  }
}

/// The per-category breakdown of what the guess earned. The numbers come from
/// the server — `reveal_item()` settles them in the same statement that reveals
/// the glass, so they can't be argued with.
class _PointsCard extends StatelessWidget {
  const _PointsCard({
    required this.rating,
    required this.item,
    required this.config,
  });

  final Rating rating;
  final TastingItem item;
  final TastingConfig config;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final rows = config
        .activeCategoriesFor(item)
        .map((category) => (category: category, points: rating.points[category]))
        .where((row) => row.points != null)
        .toList();

    return RiseIn(
      delay: const Duration(milliseconds: 350),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: SectionLabel('Dine gættepoint',
                      color: c.nightMuted),
                ),
                Text('${rating.pointsTotal ?? 0}',
                    style: GlasType.display(24, color: c.accent, height: 1)),
                const SizedBox(width: 6),
                Text('af ${config.pointsInPlayFor(item)}',
                    style: GlasType.body(12, color: c.nightMuted)),
              ],
            ),
            if (rows.isEmpty) ...[
              const SizedBox(height: 12),
              Text('Du gættede ikke på dette glas.',
                  style: GlasType.body(13, color: c.nightMuted)),
            ] else ...[
              const SizedBox(height: 12),
              for (final row in rows) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(row.category.label,
                          style: GlasType.body(13, color: c.nightInk)),
                    ),
                    Text('${row.points!.got}',
                        style: GlasType.mono(12, color: c.nightInk)),
                    const SizedBox(width: 6),
                    Text('/ ${row.points!.max}',
                        style: GlasType.mono(11, color: c.nightMuted)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
