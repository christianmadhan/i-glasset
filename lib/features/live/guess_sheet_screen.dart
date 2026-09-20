import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/vocabulary.dart';
import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/utils/formatting.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/tasting_config.dart';
import 'rating_controller.dart';

/// "Smagsskema" — the guess. Only the categories the host switched on appear,
/// and each one states what it's worth before you spend time on it.
class GuessSheetScreen extends ConsumerStatefulWidget {
  const GuessSheetScreen({
    super.key,
    required this.tastingId,
    required this.itemId,
  });

  final String tastingId;
  final String itemId;

  @override
  ConsumerState<GuessSheetScreen> createState() => _GuessSheetScreenState();
}

class _GuessSheetScreenState extends ConsumerState<GuessSheetScreen> {
  final _notes = TextEditingController();
  bool _notesLoaded = false;

  // Notes the player typed themselves, kept for the life of the screen so a
  // custom aroma stays visible as a chip after it's been added.
  final _customAromas = <String>{};
  final _customFlavours = <String>{};
  final _customGrapes = <String>{};
  final _customCountries = <String>{};
  final _customRegions = <String>{};
  final _customExtras = <String>{};

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  RatingController get _controller =>
      ref.read(ratingProvider(widget.itemId).notifier);

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final tasting = ref.watch(tastingProvider(widget.tastingId)).value;
    final rating = ref.watch(ratingProvider(widget.itemId)).value;
    final items = ref.watch(itemsProvider(widget.tastingId)).value;

    if (tasting == null || rating == null) {
      return Scaffold(
        backgroundColor: c.paper,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }

    if (!_notesLoaded) {
      _notesLoaded = true;
      _notes.text = rating.notes ?? '';
    }

    final config = tasting.config;
    final item = items?.where((i) => i.id == widget.itemId).firstOrNull;
    final position = item?.position ?? tasting.currentPosition;

    return PopScope(
      // Whatever is on screen is saved as soon as the sheet closes, however
      // it's closed.
      onPopInvokedWithResult: (_, _) => _controller.save(),
      child: PaperScreen(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
        children: [
          Row(
            children: [
              BackLink('← Glas #$position', onTap: () => context.pop()),
              const Spacer(),
              GlasTap(
                onTap: () => context.pop(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('Færdig',
                      style: GlasType.body(13.5, color: c.accent)),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gæt glas #$position',
                  style: GlasType.display(28, color: c.ink)),
              const SizedBox(height: 5),
              Text(
                config.guessOn
                    ? '${config.pointsInPlayFor(item)} point i spil på dette glas. '
                        'Gæt det, du tør — det, du lader stå, giver bare 0.'
                    : 'Ingen gættekonkurrence i denne smagning. '
                        'Skriv dine egne noter.',
                style: GlasType.body(13, color: c.muted, height: 1.5),
              ),
            ],
          ),

          if (config.isOn(GuessCategory.duft))
            _NoteCard(
              title: 'Duft',
              rule: config.ruleText(GuessCategory.duft),
              options: [...Vocabulary.aromas, ..._customAromas],
              selected: rating.guessAromas,
              max: Vocabulary.maxNotes,
              placeholder: 'Egen duftnote',
              onToggle: _controller.toggleAroma,
              onAdd: (value) {
                setState(() => _customAromas.add(value));
                _controller.toggleAroma(value);
              },
            ),

          if (config.isOn(GuessCategory.smag))
            _NoteCard(
              title: 'Smag',
              rule: config.ruleText(GuessCategory.smag),
              options: [...Vocabulary.flavours, ..._customFlavours],
              selected: rating.guessFlavours,
              max: Vocabulary.maxNotes,
              placeholder: 'Egen smagsnote',
              onToggle: _controller.toggleFlavour,
              onAdd: (value) {
                setState(() => _customFlavours.add(value));
                _controller.toggleFlavour(value);
              },
            ),

          if (config.isOn(GuessCategory.drue))
            _SingleChoiceCard(
              title: 'Drue',
              rule: config.ruleText(GuessCategory.drue),
              options: [...Vocabulary.grapes, ..._customGrapes],
              selected: rating.guessGrape,
              placeholder: 'Egen drue',
              onSelected: _controller.setGrape,
              onAdd: (value) {
                setState(() => _customGrapes.add(value));
                _controller.setGrape(value);
              },
            ),

          if (config.isOn(GuessCategory.pris))
            _SliderCard(
              title: 'Pris',
              rule: config.ruleText(GuessCategory.pris),
              value: rating.guessPrice ?? 250,
              display: formatMoney(rating.guessPrice ?? 250),
              min: Vocabulary.priceMin,
              max: Vocabulary.priceMax,
              step: Vocabulary.priceStep,
              minLabel: formatMoney(Vocabulary.priceMin),
              maxLabel: formatMoney(Vocabulary.priceMax),
              onChanged: _controller.setPrice,
            ),

          if (config.isOn(GuessCategory.alkohol))
            _SliderCard(
              title: 'Alkohol',
              rule: config.ruleText(GuessCategory.alkohol),
              value: rating.guessAbv ?? 13.5,
              display: formatAbv(rating.guessAbv ?? 13.5),
              min: Vocabulary.abvMin,
              max: Vocabulary.abvMax,
              step: Vocabulary.abvStep,
              minLabel: '8 %',
              maxLabel: '20 %',
              onChanged: _controller.setAbv,
            ),

          if (config.isOn(GuessCategory.argang))
            _SliderCard(
              title: 'Årgang',
              rule: config.ruleText(GuessCategory.argang),
              value: (rating.guessVintage ?? 2020).toDouble(),
              display: '${rating.guessVintage ?? 2020}',
              min: Vocabulary.vintageMin,
              max: Vocabulary.vintageMax,
              step: 1,
              minLabel: '1990',
              maxLabel: '2026',
              onChanged: (v) => _controller.setVintage(v.round()),
            ),

          if (config.isOn(GuessCategory.region))
            _RegionCard(
              rule: config.ruleText(GuessCategory.region),
              countries: [...Vocabulary.countries, ..._customCountries],
              regions: [...Vocabulary.regions, ..._customRegions],
              country: rating.guessCountry,
              region: rating.guessRegion,
              onCountry: _controller.setCountry,
              onRegion: _controller.setRegion,
              onAddCountry: (value) {
                setState(() => _customCountries.add(value));
                _controller.setCountry(value);
              },
              onAddRegion: (value) {
                setState(() => _customRegions.add(value));
                _controller.setRegion(value);
              },
            ),

          if (config.isOn(GuessCategory.ekstra) && item?.hasExtra == true)
            _ExtraCard(
              rule: config.ruleText(GuessCategory.ekstra),
              options: [...Vocabulary.extras, ..._customExtras],
              selected: rating.guessExtra,
              onSelected: _controller.setExtra,
              onAdd: (value) {
                setState(() => _customExtras.add(value));
                _controller.setExtra(value);
              },
            ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Egne noter'),
              const SizedBox(height: 8),
              GlasField(
                hint: 'Mørk kirsebær, urter, tobak…',
                controller: _notes,
                minLines: 4,
                maxLines: 8,
                onChanged: _controller.setNotes,
              ),
            ],
          ),

          GlasButton(
            label: 'Færdig med gættet',
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

/// Shared frame: title on the left, what it's worth on the right.
class _GuessCard extends StatelessWidget {
  const _GuessCard({
    required this.title,
    required this.rule,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String rule;
  final Widget child;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GlasType.body(15, color: c.ink)),
                    const SizedBox(height: 3),
                    Text(rule.toUpperCase(),
                        style:
                            GlasType.label(10, color: c.muted, tracking: 0.08)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: GlasType.body(12.5, color: c.muted)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Multi-select notes, capped, with a field for your own.
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.title,
    required this.rule,
    required this.options,
    required this.selected,
    required this.max,
    required this.placeholder,
    required this.onToggle,
    required this.onAdd,
  });

  final String title;
  final String rule;
  final List<String> options;
  final List<String> selected;
  final int max;
  final String placeholder;
  final void Function(String value, {int max}) onToggle;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return _GuessCard(
      title: title,
      rule: rule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChipWrap(
            spacing: 6,
            children: [
              for (final option in {...options, ...selected})
                GlasChip(
                  label: option,
                  dense: true,
                  selected: selected.contains(option),
                  onTap: () => onToggle(option, max: max),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${selected.length} af $max gæt',
              style: GlasType.body(12, color: c.muted)),
          const SizedBox(height: 12),
          _AddChipField(placeholder: placeholder, onAdd: onAdd),
        ],
      ),
    );
  }
}

/// Pick exactly one, or none.
class _SingleChoiceCard extends StatelessWidget {
  const _SingleChoiceCard({
    required this.title,
    required this.rule,
    required this.options,
    required this.selected,
    required this.placeholder,
    required this.onSelected,
    required this.onAdd,
  });

  final String title;
  final String rule;
  final List<String> options;
  final String? selected;
  final String placeholder;
  final ValueChanged<String?> onSelected;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    return _GuessCard(
      title: title,
      rule: rule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChipWrap(
            spacing: 6,
            children: [
              for (final option in {...options, ?selected})
                GlasChip(
                  label: option,
                  dense: true,
                  selected: selected == option,
                  onTap: () => onSelected(option),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _AddChipField(placeholder: placeholder, onAdd: onAdd),
        ],
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.title,
    required this.rule,
    required this.value,
    required this.display,
    required this.min,
    required this.max,
    required this.step,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
  });

  final String title;
  final String rule;
  final double value;
  final String display;
  final double min;
  final double max;
  final double step;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return _GuessCard(
      title: title,
      rule: rule,
      trailing: Text(display, style: GlasType.display(22, color: c.ink)),
      child: Column(
        children: [
          GlasSlider(
            value: value,
            min: min,
            max: max,
            step: step,
            onChanged: onChanged,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: GlasType.mono(10, color: c.muted)),
              Text(maxLabel, style: GlasType.mono(10, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.rule,
    required this.countries,
    required this.regions,
    required this.country,
    required this.region,
    required this.onCountry,
    required this.onRegion,
    required this.onAddCountry,
    required this.onAddRegion,
  });

  final String rule;
  final List<String> countries;
  final List<String> regions;
  final String? country;
  final String? region;
  final ValueChanged<String?> onCountry;
  final ValueChanged<String?> onRegion;
  final ValueChanged<String> onAddCountry;
  final ValueChanged<String> onAddRegion;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return _GuessCard(
      title: 'Land og region',
      rule: rule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChipWrap(
            spacing: 6,
            children: [
              for (final option in {...countries, ?country})
                GlasChip(
                  label: option,
                  dense: true,
                  selected: country == option,
                  onTap: () => onCountry(option),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _AddChipField(placeholder: 'Andet land', onAdd: onAddCountry),
          const SizedBox(height: 13),
          Divider(color: c.line, height: 1),
          const SizedBox(height: 13),
          ChipWrap(
            spacing: 6,
            children: [
              for (final option in {...regions, ?region})
                GlasChip(
                  label: option,
                  dense: true,
                  selected: region == option,
                  onTap: () => onRegion(option),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _AddChipField(placeholder: 'Anden region', onAdd: onAddRegion),
        ],
      ),
    );
  }
}

class _ExtraCard extends StatelessWidget {
  const _ExtraCard({
    required this.rule,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.onAdd,
  });

  final String rule;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return _GuessCard(
      title: 'Det ekstraordinære',
      rule: rule,
      subtitle: 'Værten har markeret én ting som særlig ved dette glas.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in {...options, ?selected}) ...[
            GlasTap(
              onTap: () => onSelected(option),
              radius: 12,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected == option ? c.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == option ? c.accent : c.line,
                    width: selected == option ? 1.5 : 1,
                  ),
                ),
                child: Text(option, style: GlasType.body(13.5, color: c.ink)),
              ),
            ),
            const SizedBox(height: 7),
          ],
          _AddChipField(placeholder: 'Eget gæt', onAdd: onAdd, rounded: false),
        ],
      ),
    );
  }
}

/// "Skriv din egen" — a dashed field and an Add button. Enter works too.
class _AddChipField extends StatefulWidget {
  const _AddChipField({
    required this.placeholder,
    required this.onAdd,
    this.rounded = true,
  });

  final String placeholder;
  final ValueChanged<String> onAdd;
  final bool rounded;

  @override
  State<_AddChipField> createState() => _AddChipFieldState();
}

class _AddChipFieldState extends State<_AddChipField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onAdd(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final radius = widget.rounded ? 999.0 : 12.0;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.done,
            style: GlasType.body(12.5, color: c.ink),
            cursorColor: c.accent,
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: GlasType.body(12.5, color: c.muted),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide(color: c.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide(color: c.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide(color: c.accent),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        GlasTap(
          onTap: _submit,
          radius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: c.line),
            ),
            child: Text('Tilføj', style: GlasType.body(12.5, color: c.ink)),
          ),
        ),
      ],
    );
  }
}
