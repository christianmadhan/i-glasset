import 'package:flutter/material.dart';

/// The app mark: three figures circling a gold centre, on the brand burgundy.
///
/// The same artwork `flutter_launcher_icons` generates the home-screen icons
/// from (`assets/icon/app_icon.png` is the 1024px source), so the tile on the
/// home screen and the mark inside the app are one drawing.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 72, this.radius = 18});

  /// The tile colour, used where the mark needs to sit flush against a
  /// matching background.
  static const brandBurgundy = Color(0xFF8C1D40);

  final double size;

  /// The artwork carries its own rounded tile; this clips to the same corner so
  /// callers can size it freely without the two radii disagreeing.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/app_mark.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'I Glasset',
        ),
      ),
    );
  }
}
