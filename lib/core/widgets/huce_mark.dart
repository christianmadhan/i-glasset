import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/glas_theme.dart';

/// The HUCE wordmark, drawn from the same four stroke paths as the SVG on
/// huce.dk (viewBox 340×64, stroke 3.8, square terminals). Identical to the
/// one SmartInkøb draws, so the family reads as one hand.
class HuceWordmark extends StatelessWidget {
  const HuceWordmark({super.key, this.height = 10, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(height * 340 / 64, height),
        painter: _HuceWordmarkPainter(color ?? context.glas.ink),
      );
}

class _HuceWordmarkPainter extends CustomPainter {
  const _HuceWordmarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 64;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8 * s
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    final path = Path()
      // H
      ..moveTo(4 * s, 6 * s)
      ..lineTo(4 * s, 58 * s)
      ..moveTo(43 * s, 6 * s)
      ..lineTo(43 * s, 58 * s)
      ..moveTo(17 * s, 32 * s)
      ..lineTo(43 * s, 32 * s)
      // U
      ..moveTo(104 * s, 6 * s)
      ..lineTo(104 * s, 38 * s)
      ..cubicTo(104 * s, 66 * s, 146 * s, 66 * s, 146 * s, 38 * s)
      ..lineTo(146 * s, 6 * s)
      // E
      ..moveTo(337 * s, 6 * s)
      ..lineTo(296 * s, 6 * s)
      ..lineTo(296 * s, 58 * s)
      ..lineTo(337 * s, 58 * s)
      ..moveTo(296 * s, 32 * s)
      ..lineTo(329 * s, 32 * s);
    canvas.drawPath(path, paint);

    // C: the open arc, gap on the right.
    const r = 27.0;
    final cx = 246 - math.sqrt(r * r - 16 * 16);
    final rect = Rect.fromCircle(center: Offset(cx * s, 32 * s), radius: r * s);
    final start = math.atan2(-16, 246 - cx);
    final gap = 2 * -start;
    canvas.drawArc(rect, start, -(2 * math.pi - gap), false, paint);
  }

  @override
  bool shouldRepaint(_HuceWordmarkPainter old) => old.color != color;
}

/// The family leaf — a lens with its base at the bottom-left and its tip at
/// the top-right — in this app's colour: the gold of the icon, pale at the
/// tip, deepening towards the base. The same leaf on paper and on night.
class GlasLeaf extends StatelessWidget {
  const GlasLeaf({super.key, this.size = 8});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: const _LeafPainter(
          tip: Color(0xFFF4D890),
          base: Color(0xFFD9A441),
        ),
      );
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter({required this.tip, required this.base});

  final Color tip;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, h)
      ..quadraticBezierTo(0, 0, w, 0)
      ..quadraticBezierTo(w, h, 0, h)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(Offset(w, 0), Offset(0, h), [tip, base]),
    );
  }

  @override
  bool shouldRepaint(_LeafPainter old) => old.tip != tip || old.base != base;
}

/// "HUCE | I Glasset" with the leaf off the name's shoulder — the product
/// lockup every HUCE app opens its screens with. Reads the palette it sits
/// on, so the same widget works on paper and on night.
class HuceLockup extends StatelessWidget {
  const HuceLockup({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        HuceWordmark(height: 10, color: c.ink),
        Container(
          width: 1,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: c.ink.withValues(alpha: 0.35),
        ),
        Text('I Glasset', style: GlasType.display(14, color: c.ink, height: 1)),
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 9),
          child: GlasLeaf(size: 8),
        ),
      ],
    );
  }
}

/// The small "En HUCE app" sign-off at the foot of Profil, as every app in
/// the family ends.
class HuceFooter extends StatelessWidget {
  const HuceFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Center(
      child: Column(
        children: [
          HuceWordmark(height: 9, color: c.muted),
          const SizedBox(height: 7),
          Text('EN HUCE APP',
              style: GlasType.label(8.5, color: c.muted, tracking: 0.2)),
        ],
      ),
    );
  }
}
