import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/vocabulary.dart';
import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/models/tasting_item.dart';
import '../live/bottle_thumbnail.dart';

/// "Tilføj produkt" — the host fills in what's actually in the glass.
/// Everything on this screen is a secret until that glass is revealed.
class EditItemScreen extends ConsumerStatefulWidget {
  const EditItemScreen({
    super.key,
    required this.tastingId,
    required this.itemId,
  });

  final String tastingId;
  final String itemId;

  @override
  ConsumerState<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends ConsumerState<EditItemScreen> {
  final _name = TextEditingController();
  final _producer = TextEditingController();
  final _vintage = TextEditingController();
  final _type = TextEditingController();
  final _country = TextEditingController();
  final _region = TextEditingController();
  final _grape = TextEditingController();
  final _abv = TextEditingController();
  final _price = TextEditingController();
  final _hostNotes = TextEditingController();

  final _aromas = <String>{};
  final _flavours = <String>{};
  String? _extra;

  TastingItem? _item;
  bool _loaded = false;
  bool _busy = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final controller in [
      _name, _producer, _vintage, _type, _country,
      _region, _grape, _abv, _price, _hostNotes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _hydrate(TastingItem item) {
    if (_loaded) return;
    _loaded = true;
    _item = item;
    _name.text = item.name ?? '';
    _producer.text = item.producer ?? '';
    _vintage.text = item.vintage?.toString() ?? '';
    _type.text = item.productType ?? '';
    _country.text = item.country ?? '';
    _region.text = item.region ?? '';
    _grape.text = item.grape ?? '';
    _abv.text = item.abv?.toString().replaceAll('.', ',') ?? '';
    _price.text = item.price?.round().toString() ?? '';
    _hostNotes.text = item.hostNotes ?? '';
    _aromas.addAll(item.aromas);
    _flavours.addAll(item.flavours);
    _extra = item.extra;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (picked == null || _item == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      // The file is copied into the app's own folder first, then uploaded.
      // Only the object path, checksum and size go to the database.
      final uploaded = await ref.read(mediaServiceProvider).upload(
            tastingId: widget.tastingId,
            itemId: widget.itemId,
            source: File(picked.path),
          );

      final saved = await ref.read(tastingRepositoryProvider).saveItem(
            _item!.copyWith(
              imagePath: uploaded.remotePath,
              imageSha256: uploaded.sha256,
              imageBytes: uploaded.byteSize,
            ),
          );

      setState(() => _item = saved);
      ref.invalidate(itemsProvider(widget.tastingId));
      ref.invalidate(localImageProvider((
        tastingId: widget.tastingId,
        itemId: widget.itemId,
        path: uploaded.remotePath,
      )));
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_item == null) return;
    setState(() => _busy = true);

    try {
      await ref.read(tastingRepositoryProvider).saveItem(
            _item!.copyWith(
              name: _name.text.trim(),
              producer: _producer.text.trim(),
              productType: _type.text.trim(),
              country: _country.text.trim(),
              region: _region.text.trim(),
              grape: _grape.text.trim(),
              vintage: int.tryParse(_vintage.text.trim()),
              abv: double.tryParse(_abv.text.trim().replaceAll(',', '.')),
              price: double.tryParse(_price.text.trim().replaceAll(',', '.')),
              hostNotes: _hostNotes.text.trim(),
              aromas: _aromas.toList(),
              flavours: _flavours.toList(),
              extra: _extra,
            ),
          );
      ref.invalidate(itemsProvider(widget.tastingId));
      if (mounted) context.pop();
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showGlasConfirm(
      context,
      title: 'Slet glasset?',
      body: 'Glas ${_item?.position} fjernes fra programmet.',
      confirmLabel: 'Slet',
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(tastingRepositoryProvider).deleteItem(widget.itemId);
      ref.invalidate(itemsProvider(widget.tastingId));
      if (mounted) context.pop();
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final items = ref.watch(itemsProvider(widget.tastingId)).value;
    final item = items?.where((i) => i.id == widget.itemId).firstOrNull;

    if (item == null) {
      return Scaffold(
        backgroundColor: c.paper,
        body: Center(child: CircularProgressIndicator(color: c.accent)),
      );
    }
    _hydrate(item);
    final current = _item ?? item;

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
      gap: 20,
      children: [
        Row(
          children: [
            const BackLink('← Program'),
            const Spacer(),
            Text('Glas ${current.position}',
                style: GlasType.label(10.5, color: c.accent)),
          ],
        ),
        Text('Tilføj produkt', style: GlasType.display(28, color: c.ink)),

        Stack(
          children: [
            BottleThumbnail(
              item: current,
              height: 150,
              radius: 16,
              caption: 'flaskefoto',
              onTap: _uploading ? null : _pickPhoto,
            ),
            if (_uploading)
              Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(color: c.accent),
                ),
              ),
          ],
        ),
        Text(
          'Billedet gemmes på din egen enhed og sendes først til de andre, '
          'når du afslører glasset.',
          style: GlasType.body(12, color: c.muted, height: 1.5),
        ),

        GlasList(
          children: [
            _Field(label: 'Produkt', controller: _name, hint: 'Barbaresco'),
            _Field(
                label: 'Producent',
                controller: _producer,
                hint: 'Produttori del Barbaresco'),
            _Field(
                label: 'Årgang',
                controller: _vintage,
                hint: '2021',
                keyboardType: TextInputType.number),
            _Field(label: 'Type', controller: _type, hint: 'Rødvin'),
            _Field(label: 'Land', controller: _country, hint: 'Italien'),
            _Field(label: 'Region', controller: _region, hint: 'Piemonte'),
            _Field(label: 'Drue', controller: _grape, hint: 'Nebbiolo'),
            _Field(
                label: 'Alkohol',
                controller: _abv,
                hint: '14,0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            _Field(
                label: 'Pris',
                controller: _price,
                hint: '315',
                keyboardType: TextInputType.number),
          ],
        ),

        // The answer key for the guessing game: whichever notes the host marks
        // here are the ones a guest can score points against.
        _NoteSection(
          title: 'Rigtige duftnoter',
          subtitle: 'Deltagerne får point for de noter, de rammer',
          options: Vocabulary.aromas,
          selected: _aromas,
          onChanged: (set) => setState(() {}),
        ),
        _NoteSection(
          title: 'Rigtige smagsnoter',
          subtitle: 'Samme princip som duften',
          options: Vocabulary.flavours,
          selected: _flavours,
          onChanged: (set) => setState(() {}),
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Det ekstraordinære', style: GlasType.body(15, color: c.ink)),
            const SizedBox(height: 3),
            Text('Én ting der gør netop dette glas særligt',
                style: GlasType.body(12.5, color: c.muted)),
            const SizedBox(height: 10),
            ChipWrap(
              spacing: 6,
              children: [
                for (final option in {...Vocabulary.extras, ?_extra})
                  GlasChip(
                    label: option,
                    dense: true,
                    selected: _extra == option,
                    onTap: () =>
                        setState(() => _extra = _extra == option ? null : option),
                  ),
              ],
            ),
          ],
        ),

        GlasField(
          label: 'Værtsnoter (skjult for deltagere)',
          hint: 'Dekanteres 1 time før. Serveres som glas 3.',
          controller: _hostNotes,
          minLines: 3,
          maxLines: 5,
        ),

        GlasButton(
          label: _busy ? 'Gemmer…' : 'Gem glas',
          enabled: !_busy,
          onTap: _save,
        ),
        Center(
          child: GlasTap(
            onTap: _delete,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text('Slet glasset',
                  style: GlasType.body(13.5, color: c.muted)),
            ),
          ),
        ),
      ],
    );
  }
}

/// A label-and-value row inside the hairline-separated product table.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: GlasType.body(13, color: c.muted)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: GlasType.body(14.5, color: c.ink),
              cursorColor: c.accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GlasType.body(14.5, color: c.muted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteSection extends StatefulWidget {
  const _NoteSection({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_NoteSection> createState() => _NoteSectionState();
}

class _NoteSectionState extends State<_NoteSection> {
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _add() {
    final value = _custom.text.trim();
    if (value.isEmpty) return;
    setState(() {
      widget.selected.add(value);
      _custom.clear();
    });
    widget.onChanged(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: GlasType.body(15, color: c.ink)),
          const SizedBox(height: 3),
          Text(widget.subtitle, style: GlasType.body(12.5, color: c.muted)),
          const SizedBox(height: 12),
          ChipWrap(
            spacing: 6,
            children: [
              for (final option in {...widget.options, ...widget.selected})
                GlasChip(
                  label: option,
                  dense: true,
                  selected: widget.selected.contains(option),
                  onTap: () {
                    setState(() {
                      widget.selected.contains(option)
                          ? widget.selected.remove(option)
                          : widget.selected.add(option);
                    });
                    widget.onChanged(widget.selected);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  onSubmitted: (_) => _add(),
                  style: GlasType.body(12.5, color: c.ink),
                  cursorColor: c.accent,
                  decoration: InputDecoration(
                    hintText: 'Egen note',
                    hintStyle: GlasType.body(12.5, color: c.muted),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: c.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: c.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: c.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              GlasTap(
                onTap: _add,
                radius: 999,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.line),
                  ),
                  child:
                      Text('Tilføj', style: GlasType.body(12.5, color: c.ink)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
