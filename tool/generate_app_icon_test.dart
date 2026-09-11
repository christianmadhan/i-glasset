import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/core/widgets/app_mark.dart';

/// Renders the app mark to `assets/icon/app_icon.png`, the source
/// `flutter_launcher_icons` generates every platform size from.
///
/// It lives as a test because that's the cheapest way to get a Flutter engine
/// with a real canvas. `flutter test` only walks `test/`, so it stays out of
/// the normal suite. Run it when the mark changes:
///
/// ```bash
/// flutter test tool/generate_app_icon_test.dart
/// ```
///
/// Replace the whole thing the day the real brand artwork arrives — point
/// `flutter_launcher_icons` at that PNG instead.
void main() {
  testWidgets('writes the 1024px app icon', (tester) async {
    const size = 1024.0;

    // runAsync: encoding a picture to PNG goes through the real engine, which
    // testWidgets' fake clock would otherwise never let complete.
    await tester.runAsync(() async {

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

      // The store icon is square and un-rounded: iOS applies the mask itself, and
      // a pre-rounded icon shows dark corners behind it.
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, size, size),
        Paint()..color = AppMark.brandBurgundy,
      );

      // Centre the glass at the same proportions the in-app mark uses.
      const glassWidth = size * 0.46;
      const glassHeight = size * 0.56;
      canvas.save();
      canvas.translate((size - glassWidth) / 2, (size - glassHeight) / 2);
      const GlasMarkPainter(Color(0xFFF7F1EA))
          .paint(canvas, const Size(glassWidth, glassHeight));
      canvas.restore();

      final image = await recorder.endRecording().toImage(
            size.toInt(),
            size.toInt(),
          );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);

      final file = File('assets/icon/app_icon.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());

      expect(await file.length(), greaterThan(1000));
      // ignore: avoid_print — this is a tool; the path is its output.
      print('wrote ${file.path} (${await file.length()} bytes)');
    });
  });
}
