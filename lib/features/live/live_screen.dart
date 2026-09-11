import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/rating.dart';
import '../../data/models/tasting.dart';
import '../../data/models/tasting_item.dart';
import 'rating_controller.dart';

/// "Live tasting" — the glass in front of you, still hidden.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key, required this.tastingId});

  final String tastingId;

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  final _notes = TextEditingController();
  String? _notesForItem;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

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

    // When the host reveals this glass, every device follows.
    ref.listen(itemsProvider(widget.tastingId), (_, next) {
      final revealed = next.value
          ?.where((i) => i.position == position && i.isRevealed)
          .isNotEmpty;
      if (revealed == true && mounted) {
        context.pushReplacement('/tastings/${widget.tastingId}/reveal');
      }
    });

    final ratingAsync = ref.watch(ratingProvider(item.id));
    final rating = ratingAsync.value;

    if (rating == null) {
      return Scaffold(
        backgroundColor: c.night,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    // Keep the notes field in step when the room moves to the next glass.
    if (_notesForItem != item.id) {
      _notesForItem = item.id;
      _notes.text = rating.notes ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(ratingProvider(item.id).notifier).seedDefaults(tasting.config);
        }
      });
    }

    final isHost = tasting.isHostedBy(ref.watch(currentUserIdProvider));
    final scale = tasting.config.scale;

    return NightScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
      gap: 22,
      children: [
        _Progress(
          title: tasting.title,
          position: position,
          total: items.length,
        ),

        _HiddenGlass(position: position),

        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Din karakter',
                    style: GlasType.body(13, color: c.nightMuted)),
                const Spacer(),
                Text(
                  scale.format(rating.score ?? 1),
                  style: GlasType.display(30, color: c.nightInk, height: 1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlasSlider(
              value: scale.display(rating.score ?? 1),
              min: 1,
              max: scale.max.toDouble(),
              step: scale.step,
              height: 44,
              radius: 12,
              track: Colors.white.withValues(alpha: 0.07),
              onChanged: (v) => ref
                  .read(ratingProvider(item.id).notifier)
                  .setScore(scale.store(v)),
              overlay: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1',
                        style: GlasType.mono(10.5, color: c.nightMuted)),
                    Text('${scale.max}',
                        style: GlasType.mono(10.5, color: c.nightMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            _GuessLink(
              tasting: tasting,
              rating: rating,
              onTap: () async {
                await context.push(
                  '/tastings/${widget.tastingId}/sheet?item=${item.id}',
                );
                await ref.read(ratingProvider(item.id).notifier).save();
              },
            ),

            const SizedBox(height: 12),
            NightField(
              hint: 'Hvad smager du?',
              controller: _notes,
              minLines: 3,
              maxLines: 6,
              onChanged: (value) =>
                  ref.read(ratingProvider(item.id).notifier).setNotes(value),
            ),
          ],
        ),

        if (!rating.isSubmitted)
          GlasButton(
            label: _busy ? 'Sender…' : 'Send bedømmelse',
            tone: GlasButtonTone.paper,
            enabled: !_busy && _canSubmit(tasting, rating),
            onTap: () => _submit(item),
          )
        else
          _SubmittedPanel(
            tastingId: widget.tastingId,
            item: item,
            isHost: isHost,
            hostName: tasting.hostName,
            onEdit: () =>
                ref.read(ratingProvider(item.id).notifier).unsubmit(),
            onReveal: _busy ? null : () => _reveal(item),
          ),
      ],
    );
  }

  bool _canSubmit(Tasting tasting, Rating rating) {
    if (rating.score == null) return false;
    if (tasting.config.requireNotes &&
        (rating.notes == null || rating.notes!.trim().isEmpty)) {
      return false;
    }
    return true;
  }

  Future<void> _submit(TastingItem item) async {
    setState(() => _busy = true);
    try {
      await ref.read(ratingProvider(item.id).notifier).submit();
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reveal(TastingItem item) async {
    setState(() => _busy = true);
    try {
      await ref.read(tastingRepositoryProvider).revealItem(item.id);
      ref.invalidate(itemsProvider(widget.tastingId));
      ref.invalidate(ratingsProvider(widget.tastingId));
      if (mounted) {
        context.pushReplacement('/tastings/${widget.tastingId}/reveal');
      }
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.title,
    required this.position,
    required this.total,
  });

  final String title;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title · glas $position af $total',
            style: GlasType.body(13, color: c.nightMuted)),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              if (i > 1) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: i < position
                        ? c.accent
                        : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The blind glass: a drawn bowl with a little wine in it, and nothing else.
class _HiddenGlass extends StatefulWidget {
  const _HiddenGlass({required this.position});

  final int position;

  @override
  State<_HiddenGlass> createState() => _HiddenGlassState();
}

class _HiddenGlassState extends State<_HiddenGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (context, _) => FractionalTranslation(
                  translation: Offset(-1.2 + _sweep.value * 3.2, 0),
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 78,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22)),
                      right: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22)),
                      bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.elliptical(28, 34),
                      bottomRight: Radius.elliptical(28, 34),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 34,
                      color: c.accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Glas #${widget.position}',
                    style: GlasType.display(34, color: c.nightInk)),
                const SizedBox(height: 10),
                Text('Produktet er skjult',
                    style: GlasType.label(10.5, color: c.nightMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The row that leads into the guess sheet, and reports how far along you are.
class _GuessLink extends StatelessWidget {
  const _GuessLink({
    required this.tasting,
    required this.rating,
    required this.onTap,
  });

  final Tasting tasting;
  final Rating rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final config = tasting.config;

    final summary = config.guessOn
        ? '${rating.answeredCount(config)} af '
            '${config.activeCategories.length} kategorier gættet · '
            '${config.pointsInPlay} point i spil'
        : 'Gættekonkurrencen er slået fra i denne smagning';

    return GlasTap(
      onTap: config.guessOn ? onTap : null,
      radius: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal:
                BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gæt vinen · valgfrit',
                      style: GlasType.body(14.5, color: c.nightInk)),
                  const SizedBox(height: 2),
                  Text(summary,
                      style: GlasType.body(12, color: c.nightMuted)),
                ],
              ),
            ),
            if (config.guessOn)
              Text('›', style: GlasType.body(16, color: c.nightMuted)),
          ],
        ),
      ),
    );
  }
}

/// After you've sent: who else has, and — for the host — the reveal.
class _SubmittedPanel extends ConsumerWidget {
  const _SubmittedPanel({
    required this.tastingId,
    required this.item,
    required this.isHost,
    required this.hostName,
    required this.onEdit,
    required this.onReveal,
  });

  final String tastingId;
  final TastingItem item;
  final bool isHost;
  final String? hostName;
  final VoidCallback onEdit;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final people = ref.watch(participantCountProvider(tastingId)).value ??
        ref.watch(participantsProvider(tastingId)).value?.length ??
        0;

    // Counts other people's submissions only where the tasting's visibility
    // setting lets this device see them at all.
    final submitted = (ref.watch(ratingsProvider(tastingId)).value ?? [])
        .where((r) => r.tastingItemId == item.id && r.submittedAt != null)
        .length;

    return RiseIn(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              children: [
                const PulseDot(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sendt · venter på de andre',
                          style: GlasType.body(14, color: c.nightInk)),
                      const SizedBox(height: 2),
                      Text(
                        people == 0
                            ? 'Glas #${item.position}'
                            : '$submitted af $people har bedømt '
                                'glas #${item.position}',
                        style: GlasType.body(12, color: c.nightMuted),
                      ),
                    ],
                  ),
                ),
                GlasTap(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child:
                        Text('Ret', style: GlasType.body(12.5, color: c.accent)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isHost)
            GlasButton(
              label: 'Afslør produkt',
              tone: GlasButtonTone.accent,
              enabled: onReveal != null,
              onTap: onReveal,
            )
          else
            Center(
              child: Text(
                hostName == null
                    ? 'Værten afslører, når alle er klar'
                    : '$hostName afslører, når alle er klar',
                style: GlasType.body(13, color: c.nightMuted),
              ),
            ),
        ],
      ),
    );
  }
}
