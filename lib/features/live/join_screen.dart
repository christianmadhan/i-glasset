import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/providers.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glas_widgets.dart';
import '../../data/peer/tasting_guest.dart';

/// "Deltag i smagning" — six characters and you're in the room.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.prefilledCode});

  final String? prefilledCode;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.prefilledCode ?? '');
  final _focus = FocusNode();
  bool _busy = false;

  static const _length = 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _code => _controller.text;

  Future<void> _join() async {
    if (_code.length < 4) return;
    setState(() => _busy = true);

    try {
      final tastingId =
          await ref.read(tastingRepositoryProvider).joinByCode(_code);
      ref.invalidate(myTastingsProvider);
      if (mounted) context.pushReplacement('/tastings/$tastingId/lobby');
    } on Object catch (error) {
      if (mounted) showGlasError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas.onNight;
    final ready = _code.length >= 4;

    // Locally, hosts announce themselves on the Wi-Fi, so the code is a
    // convenience rather than the only way in.
    final nearby = Env.isLocal
        ? (ref.watch(nearbyTastingsProvider).value ?? const <NearbyTasting>[])
        : const <NearbyTasting>[];

    return NightScreen(
      // The code boxes and the Deltag button sit at the two ends of the
      // screen, with the keyboard filling the space between.
      anchorBottom: true,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      gap: 26,
      children: [
        BackLink('← Hjem',
            color: c.nightMuted,
            onTap: () => context.canPop() ? context.pop() : context.go('/')),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deltag i smagning',
                style: GlasType.display(29, color: c.nightInk)),
            const SizedBox(height: 8),
            SizedBox(
              width: 280,
              child: Text(
                'Værten viser koden. Indtast den, så er du med i aftenens glas.',
                style: GlasType.body(13.5, color: c.nightMuted, height: 1.5),
              ),
            ),
          ],
        ),

        // The boxes are the visible control; the real field sits behind them so
        // the system keyboard, paste and autofill all still work.
        Stack(
          children: [
            GestureDetector(
              onTap: () => _focus.requestFocus(),
              child: Row(
                children: [
                  for (var i = 0; i < _length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 0.78,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.nightField,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: i == _code.length
                                  ? c.accent
                                  : c.nightFieldLine,
                              width: i == _code.length ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            i < _code.length ? _code[i] : '',
                            style: GlasType.mono(24, color: c.nightInk),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  maxLength: _length,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    TextInputFormatter.withFunction(
                      (_, next) => next.copyWith(text: next.text.toUpperCase()),
                    ),
                  ],
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _join(),
                  decoration: const InputDecoration(counterText: ''),
                ),
              ),
            ),
          ],
        ),

        if (nearby.isNotEmpty) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel('I nærheden', color: c.nightMuted),
              const SizedBox(height: 10),
              for (final tasting in nearby) ...[
                _NearbyRow(
                  tasting: tasting,
                  onTap: () {
                    _controller.text = tasting.code;
                    setState(() {});
                    _join();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ],

        const GlasSpacer(),

        GlasButton(
          label: _busy ? 'Et øjeblik…' : 'Deltag',
          tone: ready ? GlasButtonTone.accent : GlasButtonTone.outline,
          enabled: ready && !_busy,
          onTap: _join,
        ),
      ],
    );
  }
}

/// A tasting someone on this Wi-Fi is hosting right now.
class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.tasting, required this.onTap});

  final NearbyTasting tasting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasTap(
      onTap: onTap,
      radius: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.nightField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.nightFieldLine),
        ),
        child: Row(
          children: [
            const PulseDot(size: 6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tasting.title,
                      style: GlasType.body(15, color: c.nightInk)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (tasting.hostName.isNotEmpty) 'vært ${tasting.hostName}',
                      if (tasting.glasses > 0) '${tasting.glasses} glas',
                    ].join(' · '),
                    style: GlasType.body(12.5, color: c.nightMuted),
                  ),
                ],
              ),
            ),
            Text(tasting.code,
                style: GlasType.mono(14, color: c.nightMuted, tracking: 0.12)),
          ],
        ),
      ),
    );
  }
}
