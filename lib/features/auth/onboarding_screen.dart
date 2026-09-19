import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/vocabulary.dart';
import '../../core/theme/glas_theme.dart';
import '../../core/widgets/app_mark.dart';
import '../../core/widgets/glas_widgets.dart';

/// "Kom godt i gang" — the four cards that explain the evening's shape.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  static const _steps = OnboardingStep.steps;

  void _next() {
    if (_step == _steps.length - 1) {
      context.go('/');
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final step = _steps[_step];

    return PaperScreen(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      anchorBottom: true,
      gap: 26,
      children: [
        Row(
          children: [
            SectionLabel('Trin ${_step + 1} af ${_steps.length}',
                color: c.muted),
            const Spacer(),
            GlasTap(
              onTap: () => context.go('/'),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text('Spring over',
                    style: GlasType.body(13.5, color: c.muted)),
              ),
            ),
          ],
        ),
        _Mark(mark: step.mark),
        Column(
          key: ValueKey(_step),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(step.title,
                style: GlasType.display(28, color: c.ink, height: 1.2)),
            const SizedBox(height: 10),
            Text(step.body,
                style: GlasType.body(15, color: c.muted, height: 1.55)),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              Expanded(
                child: GestureDetector(
                  key: ValueKey('guide-dot-$i'),
                  onTap: () => setState(() => _step = i),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i == _step ? c.accent : c.accentSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const GlasSpacer(),
        Row(
          children: [
            if (_step > 0) ...[
              GlasTap(
                onTap: () => setState(() => _step--),
                radius: 15,
                child: Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: c.line),
                  ),
                  child: Text('←', style: GlasType.body(18, color: c.muted)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: GlasButton(
                label: _step == _steps.length - 1 ? 'Kom i gang' : 'Videre',
                onTap: _next,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The dark card with the step numeral, and the slow light sweep across it.
class _Mark extends StatelessWidget {
  const _Mark({required this.mark});

  final String mark;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        color: c.night,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: GlasSweep(
                width: 70,
                opacity: 0.05,
                period: Duration(seconds: 5),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppMark(size: 80, radius: 20),
                const SizedBox(height: 18),
                Text(
                  mark,
                  style: GlasType.display(54,
                      color: c.accentNight, height: 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
