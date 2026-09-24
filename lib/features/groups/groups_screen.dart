import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../core/widgets/huce_mark.dart';
import '../../data/models/group.dart';
import '../home/home_screen.dart' show GroupRow;

/// "Find grupper" — your clubs, plus the open ones you could join.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final mine = ref.watch(myGroupsProvider).value ?? const <Group>[];
    final discovered = ref.watch(discoverGroupsProvider);

    final mineIds = mine.map((g) => g.id).toSet();
    final open = (discovered.value ?? const <Group>[])
        .where((g) => !mineIds.contains(g.id) || g.myStatusPending)
        .toList();

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HuceLockup(),
            const SizedBox(height: 18),
            Text('Grupper', style: GlasType.display(29, color: c.ink)),
          ],
        ),
        GlasField(
          hint: 'Søg efter navn eller kategori',
          controller: _search,
          onChanged: (value) =>
              ref.read(groupSearchProvider.notifier).set(value),
        ),
        ButtonRow(
          children: [
            GlasButton(
              label: 'Opret gruppe',
              height: 48,
              onTap: () => context.push('/groups/new'),
            ),
            GlasButton(
              label: 'Brug invitation',
              height: 48,
              tone: GlasButtonTone.outline,
              onTap: _promptForInvite,
            ),
          ],
        ),

        if (mine.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Dine grupper'),
              const SizedBox(height: 10),
              for (final group in mine) ...[
                GroupRow(
                  group: group,
                  trailing: group.myStatusPending
                      ? Text('Afventer',
                          style: GlasType.body(12.5, color: c.muted))
                      : null,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Åbne grupper'),
            const SizedBox(height: 10),
            if (discovered.isLoading)
              const _Loading()
            else if (open.isEmpty)
              _NoResults(onCreate: () => context.push('/groups/new'))
            else
              for (final group in open) ...[
                _DiscoverRow(group: group),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ],
    );
  }

  Future<void> _promptForInvite() async {
    final controller = TextEditingController();
    final c = context.glas;

    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Brug invitation',
            style: GlasType.display(20, color: c.ink)),
        content: GlasField(
          hint: 'GRP-7F2A',
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          style: GlasType.mono(15, color: c.ink, tracking: 0.1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annullér', style: GlasType.body(14, color: c.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Tilmeld', style: GlasType.body(14, color: c.accent)),
          ),
        ],
      ),
    );

    if (code == null || code.trim().isEmpty || !mounted) return;

    try {
      final groupId = await ref.read(groupRepositoryProvider).joinByCode(code);
      ref.invalidate(myGroupsProvider);
      if (mounted) context.push('/groups/$groupId');
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    }
  }
}

class _DiscoverRow extends ConsumerWidget {
  const _DiscoverRow({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.glas;
    final pending = group.myStatusPending;
    final joined = group.isMember;

    final label = joined
        ? 'Medlem'
        : pending
            ? 'Anmodning sendt'
            : group.access == GroupAccess.open
                ? 'Tilmeld'
                : 'Anmod';

    return GlasCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => context.push('/groups/${group.id}'),
      child: Row(
        children: [
          Monogram(group.initials),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: GlasType.body(14.5, color: c.ink, height: 1.25)),
                const SizedBox(height: 3),
                Text(group.meta, style: GlasType.body(12, color: c.muted)),
                const SizedBox(height: 3),
                Text(group.access.label.toUpperCase(),
                    style: GlasType.label(10, color: c.muted, tracking: 0.08)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GlasTap(
            onTap: (joined || pending)
                ? null
                : () async {
                    try {
                      final active = await ref
                          .read(groupRepositoryProvider)
                          .requestMembership(group.id);
                      ref.invalidate(myGroupsProvider);
                      ref.invalidate(discoverGroupsProvider);
                      if (context.mounted && active) {
                        context.push('/groups/${group.id}');
                      }
                    } on Object catch (error) {
                      if (context.mounted) showGlasError(context, error);
                    }
                  },
            radius: 999,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: (joined || pending) ? Colors.transparent : c.ink,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: (joined || pending) ? c.line : c.ink),
              ),
              child: Text(
                label,
                style: GlasType.body(12.5,
                    color: (joined || pending) ? c.muted : c.paper),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return DottedPanel(
      child: Column(
        children: [
          Text('Ingen grupper matcher søgningen',
              textAlign: TextAlign.center,
              style: GlasType.body(14, color: c.muted)),
          const SizedBox(height: 10),
          GlasTap(
            onTap: onCreate,
            radius: 999,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: c.line),
              ),
              child: Text('Opret den selv',
                  style: GlasType.body(12.5, color: c.ink)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.glas.accent,
            ),
          ),
        ),
      );
}

/// The dashed empty-state frame.
class DottedPanel extends StatelessWidget {
  const DottedPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }
}
