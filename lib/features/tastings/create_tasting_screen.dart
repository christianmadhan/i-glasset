import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/vocabulary.dart';
import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/group.dart';
import '../../data/models/tasting_config.dart';

/// "Opret smagning" — step one of two. Everything here lands in the tasting
/// row and its config document; the glasses come next.
class CreateTastingScreen extends ConsumerStatefulWidget {
  const CreateTastingScreen({super.key, this.groupId});

  final String? groupId;

  @override
  ConsumerState<CreateTastingScreen> createState() =>
      _CreateTastingScreenState();
}

class _CreateTastingScreenState extends ConsumerState<CreateTastingScreen> {
  final _title = TextEditingController();
  final _theme = TextEditingController();
  final _description = TextEditingController();
  final _code = TextEditingController();

  DateTime? _when;
  String? _groupId;
  String _category = 'Vin';
  int _glasses = 6;
  TastingConfig _config = const TastingConfig();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
  }

  @override
  void dispose() {
    _title.dispose();
    _theme.dispose();
    _description.dispose();
    _code.dispose();
    super.dispose();
  }

  void _setChoice(String key, String value) {
    setState(() {
      _config = switch (key) {
        'blind' => _config.copyWith(blind: value),
        'reveal' => _config.copyWith(reveal: value),
        'order' => _config.copyWith(order: value),
        'scale' => _config.copyWith(scale: RatingScale.fromWire(value)),
        'show_others' => _config.copyWith(showOthers: value),
        'timer' => _config.copyWith(timer: value),
        'code_mode' => _config.copyWith(codeMode: value),
        'guests' => _config.copyWith(guests: value),
        _ => _config,
      };
    });
  }

  String _currentChoice(String key) => switch (key) {
        'blind' => _config.blind,
        'reveal' => _config.reveal,
        'order' => _config.order,
        'scale' => _config.scale.label,
        'show_others' => _config.showOthers,
        'timer' => _config.timer,
        'code_mode' => _config.codeMode,
        'guests' => _config.guests,
        _ => '',
      };

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
      locale: const Locale('da'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when ?? now),
    );
    if (!mounted) return;

    setState(() {
      _when = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 19,
        time?.minute ?? 30,
      );
    });
  }

  Future<void> _next() async {
    if (_title.text.trim().isEmpty) {
      showGlasMessage(context, 'Smagningen skal have et navn.');
      return;
    }
    setState(() => _busy = true);

    try {
      final repo = ref.read(tastingRepositoryProvider);
      final tasting = await repo.createTasting(
        title: _title.text.trim(),
        groupId: _groupId,
        theme: _theme.text.trim(),
        description: _description.text.trim(),
        category: _category,
        scheduledFor: _when,
        config: _config,
        joinCode: _config.codeMode == 'Vælg selv' ? _code.text.trim() : null,
      );

      // Create the empty glasses so step two is a matter of filling them in.
      for (var position = 1; position <= _glasses; position++) {
        await repo.createItem(tastingId: tasting.id, position: position);
      }

      ref.invalidate(myTastingsProvider);
      if (mounted) {
        context.pushReplacement('/tastings/${tasting.id}/program');
      }
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final groups = ref.watch(myGroupsProvider).value ?? const <Group>[];
    final hostable = groups.where((g) => g.canHost).toList();

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
      children: [
        Row(
          children: [
            GlasTap(
              onTap: () => context.pop(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child:
                    Text('Annullér', style: GlasType.body(13.5, color: c.muted)),
              ),
            ),
            const Spacer(),
            SectionLabel('Trin 1 af 2', color: c.muted),
          ],
        ),
        Text('Opret smagning', style: GlasType.display(29, color: c.ink)),

        GlasField(label: 'Navn', hint: 'fx Italienske rødvine', controller: _title),

        // Date is a field-shaped button rather than a text input, so it can't
        // be typed into a format the parser won't accept.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dato', style: GlasType.body(12, color: c.muted)),
            const SizedBox(height: 6),
            GlasTap(
              onTap: _pickWhen,
              radius: 13,
              child: Container(
                height: 48,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: c.line),
                ),
                child: FitText(
                  _when == null
                      ? 'Vælg dato og tid'
                      : '${formatDate(_when)}, ${formatWhen(_when).split(' ').last}',
                  alignment: Alignment.centerLeft,
                  style: GlasType.body(15,
                      color: _when == null ? c.muted : c.ink),
                ),
              ),
            ),
          ],
        ),

        if (hostable.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gruppe', style: GlasType.body(12, color: c.muted)),
              const SizedBox(height: 9),
              ChipWrap(
                children: [
                  GlasChip(
                    label: 'Uden gruppe',
                    selected: _groupId == null,
                    onTap: () => setState(() => _groupId = null),
                  ),
                  for (final group in hostable)
                    GlasChip(
                      label: group.name,
                      selected: _groupId == group.id,
                      onTap: () => setState(() => _groupId = group.id),
                    ),
                ],
              ),
            ],
          ),

        GlasField(label: 'Tema', hint: 'fx Piemonte mod Toscana', controller: _theme),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kategori', style: GlasType.body(12, color: c.muted)),
            const SizedBox(height: 9),
            ChipWrap(
              children: [
                for (final category in Vocabulary.categories)
                  GlasChip(
                    label: category,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
          ],
        ),

        GlasField(
          label: 'Beskrivelse (valgfri)',
          hint: 'Seks flasker fra Piemonte og Toscana. Alt smages blindt.',
          controller: _description,
          minLines: 3,
          maxLines: 5,
        ),

        GlasCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Antal glas', style: GlasType.body(15, color: c.ink)),
                    const SizedBox(height: 3),
                    Text('Du kan tilføje produkterne i næste trin',
                        style: GlasType.body(12.5, color: c.muted)),
                  ],
                ),
              ),
              Stepper2(
                value: _glasses,
                onChanged: (v) => setState(() => _glasses = v),
              ),
            ],
          ),
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Format og regler'),
            const SizedBox(height: 12),
            for (final choice in ConfigChoice.all) ...[
              _ChoiceCard(
                choice: choice,
                selected: _currentChoice(choice.key),
                onSelected: (value) => _setChoice(choice.key, value),
              ),
              const SizedBox(height: 10),
            ],
            if (_config.codeMode == 'Vælg selv') ...[
              GlasField(
                label: 'Deltagerkode',
                hint: 'GLAS42',
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                style: GlasType.mono(15, color: c.ink, tracking: 0.14),
              ),
              const SizedBox(height: 10),
            ],
            SwitchRow(
              title: 'Kræv noter før man kan sende',
              subtitle: 'Ellers kan man nøjes med en karakter',
              value: _config.requireNotes,
              onChanged: (v) =>
                  setState(() => _config = _config.copyWith(requireNotes: v)),
            ),
          ],
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Gættekonkurrence'),
            const SizedBox(height: 12),
            SwitchRow(
              title: 'Gæt om point',
              subtitle: '${_config.pointsInPlayFor(null)} point i spil pr. glas'
                  '${_config.isOn(GuessCategory.ekstra) ? ' · +${_config.pointsFor(GuessCategory.ekstra)} på et glas med noget særligt' : ''}',
              value: _config.guessOn,
              onChanged: (v) =>
                  setState(() => _config = _config.copyWith(guessOn: v)),
            ),
            if (_config.guessOn) ...[
              const SizedBox(height: 12),
              GlasList(
                children: [
                  for (final category in GuessCategory.values)
                    if (category != GuessCategory.ekstra)
                      _CategoryRow(
                      category: category,
                      rule: _config.cats[category]!,
                      onChanged: (rule) => setState(
                          () => _config = _config.withCategory(category, rule)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Duft og smag giver 1 point pr. ramt note op til maks. '
                'Land og region deler kategoriens point. Det ekstraordinære '
                'er ikke en fast kategori: har værten markeret noget særligt '
                'ved et glas, kan der gættes på det for '
                '${_config.pointsFor(GuessCategory.ekstra)} point ekstra.',
                style: GlasType.body(12.5, color: c.muted, height: 1.5),
              ),
            ],
          ],
        ),

        GlasButton(
          label: _busy ? 'Opretter…' : 'Næste: tilføj glas',
          enabled: !_busy,
          onTap: _next,
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.selected,
    required this.onSelected,
  });

  final ConfigChoice choice;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The hint drops below the label when both won't fit on one line,
          // rather than squeezing "Karakterskala" until it splits.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            runSpacing: 2,
            children: [
              Text(choice.label, style: GlasType.body(14.5, color: c.ink)),
              Text(choice.hint.toUpperCase(),
                  style: GlasType.label(10, color: c.muted, tracking: 0.08)),
            ],
          ),
          const SizedBox(height: 11),
          ChipWrap(
            spacing: 6,
            children: [
              for (final option in choice.options)
                GlasChip(
                  label: option,
                  dense: true,
                  selected: selected == option,
                  onTap: () => onSelected(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One guess category: on/off, and what it's worth.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.rule,
    required this.onChanged,
  });

  final GuessCategory category;
  final CategoryRule rule;
  final ValueChanged<CategoryRule> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChanged(rule.copyWith(on: !rule.on)),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: rule.on ? c.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: rule.on ? c.accent : c.line,
                  width: 1.5,
                ),
              ),
              child: rule.on
                  ? Icon(Icons.check, size: 14, color: c.onAccent)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(category.label, style: GlasType.body(14, color: c.ink)),
          ),
          Stepper2(
            value: rule.points,
            min: 1,
            max: 10,
            size: 30,
            valueSize: 17,
            onChanged: (points) =>
                onChanged(rule.copyWith(points: points, on: true)),
          ),
        ],
      ),
    );
  }
}
