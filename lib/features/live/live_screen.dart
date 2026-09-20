import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/models/rating.dart';
import '../../data/models/tasting.dart';
import '../../data/models/tasting_item.dart';
import 'rating_controller.dart';
import 'tasting_exit.dart';

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

  /// The glass whose guess sheet has been opened. Until then the primary
  /// action is the guess itself, not "send" — guessing is a step of the
  /// evening, not a link to find.
  String? _guessedFor;

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
                const Spacer(),
                SectionLabel(isHost ? 'Vært' : 'Deltager', color: c.nightMuted),
              ],
            ),
            const SizedBox(height: 14),
            _Progress(
              title: tasting.title,
              position: position,
              total: items.length,
            ),
            GuestConnectionNote(isHost: isHost),
          ],
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

            if (tasting.config.guessOn)
              _GuessCard(
                tasting: tasting,
                item: item,
                rating: rating,
                opened: _guessedFor == item.id,
                onTap: () => _openGuess(item),
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

        if (!rating.isSubmitted &&
            tasting.config.guessOn &&
            _guessedFor != item.id)
          // Step two of three: the guess. Sending comes after.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlasButton(
                label: 'Gæt vinen',
                tone: GlasButtonTone.accent,
                trailing: Text('›',
                    style: GlasType.body(20, color: c.onAccent, height: 1)),
                onTap: () => _openGuess(item),
              ),
              const SizedBox(height: 10),
              Center(
                child: GlasTap(
                  onTap: _busy || !_canSubmit(tasting, rating)
                      ? null
                      : () => _submit(item),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('Send uden at gætte',
                        style: GlasType.body(13, color: c.nightMuted)),
                  ),
                ),
              ),
            ],
          )
        else if (!rating.isSubmitted)
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

  Future<void> _openGuess(TastingItem item) async {
    await context.push('/tastings/${widget.tastingId}/sheet?item=${item.id}');
    await ref.read(ratingProvider(item.id).notifier).save();
    if (mounted) setState(() => _guessedFor = item.id);
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
      // The reveal is also when the guess is scored, and the points land on
      // this glass's own rating — which the reveal screen reads. Without this
      // it goes on showing the unscored draft.
      ref.invalidate(ratingProvider(item.id));
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
class _HiddenGlass extends StatelessWidget {
  const _HiddenGlass({required this.position});

  final int position;

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
            const Positioned.fill(child: GlasSweep()),
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
                Text('Glas #$position',
                    style: GlasType.display(34, color: c.nightInk)),
                const SizedBox(height: 10),
                SectionLabel('Produktet er skjult', color: c.nightMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The row that leads into the guess sheet, and reports how far along you are.
/// The guess, as a card rather than a line: what is in play, and — once the
/// sheet has been opened — how far the guest got, with the way back in.
class _GuessCard extends StatelessWidget {
  const _GuessCard({
    required this.tasting,
    required this.item,
    required this.rating,
    required this.opened,
    required this.onTap,
  });

  final Tasting tasting;
  final TastingItem item;
  final Rating rating;
  final bool opened;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final config = tasting.config;
    final categories = config.activeCategoriesFor(item);
    final names = [
      for (final cat in categories.take(4)) cat.label.toLowerCase(),
    ].join(', ');

    return GlasTap(
      onTap: onTap,
      radius: 15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: opened ? Colors.transparent : c.accentSoft,
          border: Border.all(
            color: opened ? c.nightLine : c.accent.withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opened ? 'Dit gæt' : 'Gæt vinen',
                      style: GlasType.display(17, color: c.nightInk, height: 1.1)),
                  const SizedBox(height: 4),
                  Text(
                    opened
                        ? '${rating.answeredCount(config, item: item)} af '
                            '${categories.length} kategorier · '
                            '${config.pointsInPlayFor(item)} point i spil'
                        : '$names… · ${config.pointsInPlayFor(item)} point i spil',
                    style: GlasType.body(12.5, color: c.nightMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(opened ? 'Ret' : '›',
                style: GlasType.body(opened ? 13 : 22,
                    color: c.accent, height: 1)),
          ],
        ),
      ),
    );
  }
}

/// One name in the host's overview: a filled dot once they have sent.
class _ReadyChip extends StatelessWidget {
  const _ReadyChip({required this.name, required this.ready});

  final String name;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ready ? c.accent.withValues(alpha: 0.6) : c.nightLine,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ready ? c.accent : Colors.transparent,
              border: ready ? null : Border.all(color: c.nightMuted),
            ),
          ),
          const SizedBox(width: 8),
          Text(name,
              style: GlasType.body(12.5,
                  color: ready ? c.nightInk : c.nightMuted)),
        ],
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
    final roster = ref.watch(participantsProvider(tastingId)).value ??
        const <({Profile profile, bool isHost})>[];
    final people =
        ref.watch(participantCountProvider(tastingId)).value ?? roster.length;

    // Counts other people's submissions only where the tasting's visibility
    // setting lets this device see them at all — the host always can.
    final sent = {
      for (final r in ref.watch(ratingsProvider(tastingId)).value ?? <Rating>[])
        if (r.tastingItemId == item.id && r.submittedAt != null) r.userId,
    };
    final submitted = sent.length;

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
          if (isHost && roster.isNotEmpty) ...[
            const SizedBox(height: 10),
            // The host's overview: who is still tasting, by name.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final person in roster)
                  _ReadyChip(
                    name: person.profile.firstName,
                    ready: sent.contains(person.profile.id),
                  ),
              ],
            ),
          ],
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
