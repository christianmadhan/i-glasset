import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/tasting.dart';
import '../../data/models/tasting_item.dart';
import '../live/bottle_thumbnail.dart';

/// "Rediger smagning" — the host's running order. Glasses can be dragged into
/// place, opened for editing, and the whole thing started from here.
class ProgramScreen extends ConsumerStatefulWidget {
  const ProgramScreen({super.key, required this.tastingId});

  final String tastingId;

  @override
  ConsumerState<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends ConsumerState<ProgramScreen> {
  List<TastingItem>? _ordered;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final tastingAsync = ref.watch(tastingProvider(widget.tastingId));
    final itemsAsync = ref.watch(itemsProvider(widget.tastingId));

    final tasting = tastingAsync.value;
    final items = _ordered ?? itemsAsync.value ?? const <TastingItem>[];

    if (tasting == null) {
      return Scaffold(
        backgroundColor: c.paper,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    final isHost = tasting.isHostedBy(ref.watch(currentUserIdProvider));

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
      gap: 20,
      children: [
        Row(
          children: [
            const BackLink('← Hjem'),
            const Spacer(),
            if (isHost)
              Text('Vært', style: GlasType.label(10.5, color: c.accent)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tasting.title,
                style: GlasType.display(28, color: c.ink, height: 1.15)),
            const SizedBox(height: 5),
            Text(
              [
                if (tasting.groupName != null) tasting.groupName!,
                formatWhen(tasting.scheduledFor),
                '${items.length} glas',
              ].join(' · '),
              style: GlasType.body(13.5, color: c.muted),
            ),
          ],
        ),

        _CodePanel(tasting: tasting, isHost: isHost, onOpen: _openLobby),

        SectionLabel(
          'Rækkefølge',
          trailing: Text(
            isHost ? 'Træk for at flytte' : '${items.length} glas',
            style: GlasType.body(12.5, color: c.muted),
          ),
        ),

        if (isHost)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorderItem: (from, to) => _reorder(items, from, to),
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              child: child,
            ),
            itemBuilder: (context, index) => Padding(
              key: ValueKey(items[index].id),
              padding: const EdgeInsets.only(bottom: 8),
              child: _GlassRow(
                item: items[index],
                index: index,
                draggable: true,
                onTap: () => context.push(
                  '/tastings/${widget.tastingId}/items/${items[index].id}',
                ),
              ),
            ),
          )
        else
          for (final item in items) ...[
            _GlassRow(item: item, index: item.position - 1, draggable: false),
            const SizedBox(height: 8),
          ],

        if (isHost)
          GlasTap(
            onTap: _addGlass,
            radius: 14,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.line, width: 1.5),
              ),
              child: Text('+ Tilføj glas',
                  style: GlasType.body(14.5, color: c.muted)),
            ),
          ),

        if (isHost)
          GlasButton(
            label: _busy
                ? 'Åbner…'
                : tasting.status == TastingStatus.draft
                    ? 'Start smagning'
                    : 'Åbn lobby',
            tone: GlasButtonTone.accent,
            enabled: !_busy && items.isNotEmpty,
            onTap: _openLobby,
          ),
      ],
    );
  }

  Future<void> _reorder(List<TastingItem> items, int from, int to) async {
    // onReorderItem hands back the destination index already adjusted for the
    // removal, so this is a plain remove-then-insert.
    final next = [...items];
    final moved = next.removeAt(from);
    next.insert(to, moved);

    // Show the new order straight away; persist behind it.
    setState(() => _ordered = [
          for (var i = 0; i < next.length; i++)
            next[i].copyWith(position: i + 1),
        ]);

    try {
      await ref.read(tastingRepositoryProvider).reorderItems(next);
      ref.invalidate(itemsProvider(widget.tastingId));
    } on Object catch (error) {
      if (mounted) {
        setState(() => _ordered = null);
        showGlasError(context, error);
      }
    }
  }

  Future<void> _addGlass() async {
    final items = ref.read(itemsProvider(widget.tastingId)).value ?? [];
    try {
      final item = await ref.read(tastingRepositoryProvider).createItem(
            tastingId: widget.tastingId,
            position: items.length + 1,
          );
      setState(() => _ordered = null);
      ref.invalidate(itemsProvider(widget.tastingId));
      if (mounted) {
        context.push('/tastings/${widget.tastingId}/items/${item.id}');
      }
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    }
  }

  Future<void> _openLobby() async {
    setState(() => _busy = true);
    try {
      await ref.read(tastingRepositoryProvider).openLobby(widget.tastingId);
      ref.invalidate(tastingProvider(widget.tastingId));
      ref.invalidate(myTastingsProvider);
      if (mounted) context.push('/tastings/${widget.tastingId}/lobby');
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CodePanel extends StatelessWidget {
  const _CodePanel({
    required this.tasting,
    required this.isHost,
    required this.onOpen,
  });

  final Tasting tasting;
  final bool isHost;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return NightPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: 18,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deltagerkode',
                    style: GlasType.body(12, color: c.nightMuted)),
                const SizedBox(height: 3),
                GestureDetector(
                  onLongPress: () async {
                    await Clipboard.setData(
                        ClipboardData(text: tasting.joinCode));
                    if (context.mounted) {
                      showGlasMessage(context, 'Koden er kopieret.');
                    }
                  },
                  child: Text(
                    tasting.joinCode,
                    style:
                        GlasType.mono(24, color: c.nightInk, tracking: 0.14),
                  ),
                ),
              ],
            ),
          ),
          if (isHost)
            GlasTap(
              onTap: onOpen,
              radius: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: c.nightInk,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Åbn lobby',
                    style: GlasType.body(14, color: c.night)),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassRow extends StatelessWidget {
  const _GlassRow({
    required this.item,
    required this.index,
    required this.draggable,
    this.onTap,
  });

  final TastingItem item;
  final int index;
  final bool draggable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final named = item.name?.isNotEmpty == true;

    return GlasCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          if (draggable)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: 13),
                child: Opacity(
                  opacity: 0.35,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(height: 3),
                        Container(width: 14, height: 1.5, color: c.ink),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 22,
            child: Text('${item.position}',
                style: GlasType.display(16, color: c.muted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  named ? item.name! : 'Skjult · glas ${item.position}',
                  style: GlasType.body(14.5, color: c.ink),
                ),
                const SizedBox(height: 2),
                Text(item.hostMeta,
                    style: GlasType.body(12, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          BottleThumbnail(item: item, width: 34, height: 44),
        ],
      ),
    );
  }
}
