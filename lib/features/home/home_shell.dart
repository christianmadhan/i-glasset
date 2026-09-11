import 'package:flutter/material.dart';

import '../../core/theme/glas_theme.dart';
import '../groups/groups_screen.dart';
import '../archive/top_products_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

/// The four-tab shell. Tabs keep their own scroll position, which matters most
/// for the long archive list.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() => _index = widget.initialTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.glas.paper,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          GroupsScreen(),
          TopProductsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: GlasTabBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// The sticky bottom bar: hairline top rule, stroked icons, accent when active.
class GlasTabBar extends StatelessWidget {
  const GlasTabBar({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _tabs = [
    (label: 'Hjem', path: 'M3 10.5 12 3.5l9 7M5.5 9v11h13V9'),
    (
      label: 'Grupper',
      path: 'M9 11a3.2 3.2 0 1 0 0-6.4A3.2 3.2 0 0 0 9 11'
          'M2.5 20c0-3.3 2.9-5.6 6.5-5.6s6.5 2.3 6.5 5.6'
          'M16.2 5.2a3 3 0 0 1 0 5.9M18 14.8c2.1.7 3.5 2.5 3.5 5.2'
    ),
    (label: 'Top', path: 'M4 20V12M10 20V7M16 20v-6M22 20H2'),
    (
      label: 'Profil',
      path: 'M12 11.5a3.6 3.6 0 1 0 0-7.2 3.6 3.6 0 0 0 0 7.2'
          'M4.5 20.5c0-3.7 3.3-6.3 7.5-6.3s7.5 2.6 7.5 6.3'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Container(
      decoration: BoxDecoration(
        color: c.paper,
        border: Border(top: BorderSide(color: c.line)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: 10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: _Tab(
                label: _tabs[i].label,
                path: _tabs[i].path,
                active: i == index,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.path,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String path;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final color = active ? c.accent : c.muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(painter: _IconPainter(path, color)),
            ),
            const SizedBox(height: 6),
            Text(label, style: GlasType.body(10.5, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Draws the design's SVG tab glyphs. They're stroked 24×24 paths, so parsing
/// the handful of commands they use is cheaper than shipping an SVG package.
class _IconPainter extends CustomPainter {
  const _IconPainter(this.path, this.color);

  final String path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      _parse(path),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.path != path;

  static final _token = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|-?\d*\.?\d+(?:e-?\d+)?');

  /// A small SVG path reader.
  ///
  /// Covers the commands the design's four glyphs actually use — lines, cubic
  /// and smooth-cubic curves, quadratics and arcs — including the implicit
  /// repeat, where a command letter is followed by several coordinate sets.
  static Path _parse(String d) {
    final path = Path();
    final tokens = _token.allMatches(d).map((m) => m[0]!).toList();

    var i = 0;
    var x = 0.0, y = 0.0;
    // The reflection point for a smooth curve continuing the previous one.
    var controlX = 0.0, controlY = 0.0;
    String command = 'M';

    double next() => double.parse(tokens[i++]);
    bool isCommand(String token) => RegExp(r'^[A-Za-z]$').hasMatch(token);
    bool relative() => command == command.toLowerCase();
    double dx(double value) => relative() ? x + value : value;
    double dy(double value) => relative() ? y + value : value;

    while (i < tokens.length) {
      if (isCommand(tokens[i])) {
        command = tokens[i];
        i++;
        // "M 1 2 3 4" means move then line; the same for lowercase.
        if (command == 'M') {
          x = next();
          y = next();
          path.moveTo(x, y);
          command = 'L';
          continue;
        }
        if (command == 'm') {
          x += next();
          y += next();
          path.moveTo(x, y);
          command = 'l';
          continue;
        }
        if (command == 'Z' || command == 'z') {
          path.close();
          continue;
        }
      }
      if (i >= tokens.length) break;

      switch (command.toUpperCase()) {
        case 'L':
          x = dx(next());
          y = dy(next());
          path.lineTo(x, y);
          controlX = x;
          controlY = y;

        case 'H':
          x = dx(next());
          path.lineTo(x, y);
          controlX = x;
          controlY = y;

        case 'V':
          y = dy(next());
          path.lineTo(x, y);
          controlX = x;
          controlY = y;

        case 'C':
          final x1 = dx(next());
          final y1 = dy(next());
          final x2 = dx(next());
          final y2 = dy(next());
          x = dx(next());
          y = dy(next());
          path.cubicTo(x1, y1, x2, y2, x, y);
          controlX = x2;
          controlY = y2;

        case 'S':
          // The first control point mirrors the previous curve's second.
          final x1 = 2 * x - controlX;
          final y1 = 2 * y - controlY;
          final x2 = dx(next());
          final y2 = dy(next());
          x = dx(next());
          y = dy(next());
          path.cubicTo(x1, y1, x2, y2, x, y);
          controlX = x2;
          controlY = y2;

        case 'Q':
          final x1 = dx(next());
          final y1 = dy(next());
          x = dx(next());
          y = dy(next());
          path.quadraticBezierTo(x1, y1, x, y);
          controlX = x1;
          controlY = y1;

        case 'T':
          final x1 = 2 * x - controlX;
          final y1 = 2 * y - controlY;
          x = dx(next());
          y = dy(next());
          path.quadraticBezierTo(x1, y1, x, y);
          controlX = x1;
          controlY = y1;

        case 'A':
          final rx = next();
          final ry = next();
          final rotation = next();
          final largeArc = next() != 0;
          final sweep = next() != 0;
          x = dx(next());
          y = dy(next());
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: largeArc,
            clockwise: sweep,
          );
          controlX = x;
          controlY = y;

        default:
          i++;
      }
    }
    return path;
  }
}
