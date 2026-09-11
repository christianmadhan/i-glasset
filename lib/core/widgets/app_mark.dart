import 'package:flutter/material.dart';

import '../theme/glas_theme.dart';

/// The app mark: a wine glass on the brand burgundy tile.
///
/// PLACEHOLDER. The real artwork is `assets/i-glasset-app-icon.png` in the
/// Claude Design project, which the design API could only return truncated
/// (it exceeds the 256 KiB per-file cap), so it cannot be shipped yet. Drop the
/// full PNG into `assets/images/` and swap this widget's body for an
/// `Image.asset` — nothing else needs to change.
///
/// Until then this draws the same glass silhouette the live tasting screen
/// uses, so the app is at least consistent with itself.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 72, this.radius = 18});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF8C1D40),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size(size * 0.46, size * 0.56),
        painter: _GlassPainter(c.paper),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..color = color;

    final bowlHeight = size.height * 0.58;
    final bowl = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, bowlHeight * 0.45)
      ..arcToPoint(
        Offset(0, bowlHeight * 0.45),
        radius: Radius.elliptical(size.width * 0.5, bowlHeight * 0.62),
        clockwise: true,
      )
      ..close();
    canvas.drawPath(bowl, stroke);

    // stem and foot
    canvas.drawLine(
      Offset(size.width / 2, bowlHeight),
      Offset(size.width / 2, size.height * 0.92),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.95),
      Offset(size.width * 0.78, size.height * 0.95),
      stroke,
    );

    // the wine itself
    canvas.save();
    canvas.clipPath(bowl);
    canvas.drawRect(
      Rect.fromLTRB(0, bowlHeight * 0.28, size.width, bowlHeight),
      Paint()..color = color.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassPainter oldDelegate) => oldDelegate.color != color;
}
