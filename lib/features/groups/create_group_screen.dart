import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/vocabulary.dart';
import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/group.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _focus = <String>{'Vin'};
  GroupAccess _access = GroupAccess.approval;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      showGlasMessage(context, 'Gruppen skal have et navn.');
      return;
    }
    setState(() => _busy = true);
    try {
      final group = await ref.read(groupRepositoryProvider).create(
            name: _name.text.trim(),
            description: _description.text.trim(),
            focus: _focus.toList(),
            access: _access,
          );
      ref.invalidate(myGroupsProvider);
      ref.invalidate(discoverGroupsProvider);
      if (mounted) context.pushReplacement('/groups/${group.id}');
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas;

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
      children: [
        const BackLink('← Grupper'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opret gruppe', style: GlasType.display(29, color: c.ink)),
            const SizedBox(height: 6),
            Text('Gruppen samler jeres smagninger, stilling og historik.',
                style: GlasType.body(13.5, color: c.muted)),
          ],
        ),
        GlasField(
          label: 'Navn',
          hint: 'fx Torsdagsklubben',
          controller: _name,
        ),
        GlasField(
          label: 'Beskrivelse (valgfri)',
          hint: 'Hvem er I, og hvor ofte mødes I?',
          controller: _description,
          minLines: 3,
          maxLines: 5,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hvad smager I?', style: GlasType.body(12, color: c.muted)),
            const SizedBox(height: 9),
            ChipWrap(
              children: [
                for (final option in Vocabulary.groupFocus)
                  GlasChip(
                    label: option,
                    selected: _focus.contains(option),
                    onTap: () => setState(() {
                      _focus.contains(option)
                          ? _focus.remove(option)
                          : _focus.add(option);
                    }),
                  ),
              ],
            ),
          ],
        ),
        GlasCard(
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hvem kan blive medlem',
                  style: GlasType.body(14.5, color: c.ink)),
              const SizedBox(height: 12),
              ChipWrap(
                spacing: 6,
                children: [
                  for (final access in GroupAccess.values)
                    GlasChip(
                      label: access.label,
                      selected: _access == access,
                      dense: true,
                      onTap: () => setState(() => _access = access),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                GroupAccess.values
                    .map((a) => '${a.label}: ${a.explanation}')
                    .join('. '),
                style: GlasType.body(12.5, color: c.muted, height: 1.5),
              ),
            ],
          ),
        ),
        NightPanel(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          radius: 16,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invitationskode',
                        style: GlasType.body(12, color: c.nightMuted)),
                    const SizedBox(height: 3),
                    Text(
                      'Tildeles når gruppen oprettes',
                      style: GlasType.body(14, color: c.nightInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GlasButton(
          label: _busy ? 'Opretter…' : 'Opret gruppe',
          tone: GlasButtonTone.accent,
          enabled: !_busy,
          onTap: _create,
        ),
      ],
    );
  }
}
