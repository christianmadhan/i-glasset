import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/peer/tasting_guest.dart';

/// "← Forlad" — the way out of any screen of the evening.
///
/// Every screen from the lobby to the reveal offers this, so nobody is ever
/// stuck on a phone that has stopped hearing from the host. A guest is asked
/// first and taken off the room; the host's room stays up, the screen just
/// closes.
Future<void> leaveTasting(
  BuildContext context,
  WidgetRef ref,
  String tastingId,
) async {
  final tasting = ref.read(tastingProvider(tastingId)).value;
  final isHost = tasting?.isHostedBy(ref.read(currentUserIdProvider)) ?? false;

  if (!isHost) {
    final confirmed = await showGlasConfirm(
      context,
      title: 'Forlad smagningen?',
      body: 'Du kan komme tilbage med koden ${tasting?.joinCode ?? ''}.',
      confirmLabel: 'Forlad',
    );
    if (!confirmed) return;
    try {
      await ref.read(tastingRepositoryProvider).leave(tastingId);
      ref.invalidate(myTastingsProvider);
    } on Object catch (_) {
      // Leaving is best-effort; the screen closes either way.
    }
  }
  if (context.mounted) context.go('/');
}

/// The host putting someone out of the room. Asked first, because it also
/// deletes what that person has scored tonight and bars the code for them.
Future<void> removeParticipant(
  BuildContext context,
  WidgetRef ref,
  String tastingId,
  Profile profile,
) async {
  final confirmed = await showGlasConfirm(
    context,
    title: 'Fjern ${profile.firstName}?',
    body: 'De bliver sat ud af smagningen, deres bedømmelser i aften slettes, '
        'og koden virker ikke for dem igen.',
    confirmLabel: 'Fjern',
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref
        .read(tastingRepositoryProvider)
        .removeParticipant(tastingId, profile.id);
    ref.invalidate(participantsProvider(tastingId));
    ref.invalidate(ratingsProvider(tastingId));
  } on Object catch (error) {
    if (context.mounted) showGlasError(context, error);
  }
}

/// One line under the header telling a guest the socket to the host is down
/// and being redialled. Silent while everything is fine, and for the host,
/// who has no socket to lose.
class GuestConnectionNote extends ConsumerWidget {
  const GuestConnectionNote({super.key, required this.isHost});

  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isHost || !Env.isLocal) return const SizedBox.shrink();
    final state = ref.watch(guestStateProvider).value;
    final text = switch (state) {
      GuestState.disconnected =>
        'Forbindelsen til værten er væk · prøver igen',
      GuestState.connecting => 'Forbinder til værten',
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();

    final c = context.glas;
    return Row(
      children: [
        PulseDot(size: 6, color: c.accent),
        const SizedBox(width: 10),
        Text(text, style: GlasType.body(12.5, color: c.nightMuted)),
      ],
    );
  }
}
