import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/profile.dart';
import 'tasting_exit.dart';

/// "Venteværelse" — everyone gathers here until the host pours glass one.
///
/// Guests don't poll: [tastingStreamProvider] is a realtime subscription, so
/// the moment the host advances, this screen moves on by itself.
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key, required this.tastingId});

  final String tastingId;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.glas.onNight;

    final live = ref.watch(tastingStreamProvider(widget.tastingId)).value;
    final tasting = live ?? ref.watch(tastingProvider(widget.tastingId)).value;
    final items = ref.watch(itemsProvider(widget.tastingId)).value ?? const [];
    final people = ref.watch(participantsProvider(widget.tastingId)).value ??
        const <({Profile profile, bool isHost})>[];

    // Realtime carries the host's "start" to every device in the room.
    ref.listen(tastingStreamProvider(widget.tastingId), (_, next) {
      final value = next.value;
      if (value != null && value.currentPosition > 0 && mounted) {
        context.pushReplacement('/tastings/${widget.tastingId}/live');
      }
    });

    if (tasting == null) {
      return Scaffold(
        backgroundColor: c.night,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    final isHost = tasting.isHostedBy(ref.watch(currentUserIdProvider));
    final hostName = people.where((p) => p.isHost).firstOrNull?.profile.firstName;

    return NightScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        Row(
          children: [
            BackLink('← Forlad', color: c.nightMuted, onTap: _leave),
            const Spacer(),
            SectionLabel('Lobby', color: c.nightMuted),
          ],
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tasting.title,
                style: GlasType.display(28, color: c.nightInk, height: 1.15)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: c.nightFieldLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Kode', style: GlasType.body(12, color: c.nightMuted)),
                  const SizedBox(width: 10),
                  Text(tasting.joinCode,
                      style:
                          GlasType.mono(15, color: c.nightInk, tracking: 0.14)),
                ],
              ),
            ),
          ],
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${people.length} er med · ${items.length} glas i aften',
              style: GlasType.body(13, color: c.nightMuted),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3.4,
              children: [
                for (final person in people)
                  RiseIn(child: _PersonTile(person: person)),
              ],
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (isHost)
          GlasButton(
            label: _busy ? 'Starter…' : 'Start glas 1',
            tone: GlasButtonTone.accent,
            enabled: !_busy && items.isNotEmpty,
            onTap: _start,
          )
        else
          Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: c.nightFieldLine),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PulseDot(size: 6),
                const SizedBox(width: 10),
                Text(
                  hostName == null ? 'Venter på værten' : 'Venter på $hostName',
                  style: GlasType.body(15, color: c.nightInk),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref.read(tastingRepositoryProvider).advance(widget.tastingId, 1);
      ref.invalidate(tastingProvider(widget.tastingId));
      if (mounted) {
        context.pushReplacement('/tastings/${widget.tastingId}/live');
      }
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() => leaveTasting(context, ref, widget.tastingId);
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});

  final ({Profile profile, bool isHost}) person;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: c.nightField,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.nightLine),
      ),
      child: Row(
        children: [
          Monogram(
            person.profile.initials,
            size: 28,
            radius: 999,
            background: Colors.white.withValues(alpha: 0.1),
            foreground: c.nightInk,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              person.profile.firstName,
              overflow: TextOverflow.ellipsis,
              style: GlasType.body(13.5, color: c.nightInk),
            ),
          ),
          if (person.isHost)
            Text('VÆRT',
                style: GlasType.label(10.5, color: c.accent, tracking: 0.1)),
        ],
      ),
    );
  }
}
