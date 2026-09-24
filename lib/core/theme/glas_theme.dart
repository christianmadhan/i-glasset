import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The design's three visual directions, and the rule that on "night" screens
/// the accent switches to gold.
enum GlasThemeName {
  cellarModern('Cellar Modern'),
  cellarModernGold('Cellar Modern · guld'),
  cellar('Kælder');

  const GlasThemeName(this.label);
  final String label;
}

/// One resolved palette. Every colour the screens use comes from here — there
/// are no ad-hoc hex values in the widget tree.
@immutable
class GlasColors extends ThemeExtension<GlasColors> {
  const GlasColors({
    required this.canvas,
    required this.paper,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.night,
    required this.nightInk,
    required this.nightMuted,
    required this.accentNight,
    required this.accentNightSoft,
    required this.onAccentNight,
  });

  final Color canvas;
  final Color paper;
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color night;
  final Color nightInk;
  final Color nightMuted;
  final Color accentNight;
  final Color accentNightSoft;
  final Color onAccentNight;

  /// Borders and dividers drawn on a dark ("night") surface.
  Color get nightLine => const Color(0x24FFFFFF);
  Color get nightField => const Color(0x0DFFFFFF);
  Color get nightFieldLine => const Color(0x29FFFFFF);

  /// The night screens run the gold accent. Calling this on a palette gives
  /// the variant those screens should use.
  ///
  /// This only swaps the accent, so screen code can still reach `nightInk`,
  /// `nightMuted` and friends by name. Use [nightSurface] for the palette the
  /// *shared* widgets should see.
  GlasColors get onNight => copyWith(
        accent: accentNight,
        accentSoft: accentNightSoft,
        onAccent: onAccentNight,
      );

  /// The same palette with the surface roles remapped for a dark screen, so
  /// every shared widget — cards, chips, fields, buttons, lists — reads
  /// correctly on night without each one having to know where it is.
  GlasColors get nightSurface => onNight.copyWith(
        paper: night,
        card: nightField,
        ink: nightInk,
        muted: nightMuted,
        line: nightLine,
      );

  static const _cellarModern = GlasColors(
    canvas: Color(0xFFE8CDBD),
    paper: Color(0xFFF7F1EA),
    card: Color(0xFFFFFCF7),
    ink: Color(0xFF2D3A32),
    muted: Color(0xFF5F6B62),
    line: Color(0x212D3A32),
    accent: Color(0xFF8C1D40),
    accentSoft: Color(0x1C8C1D40),
    onAccent: Color(0xFFFFFCF7),
    night: Color(0xFF2D3A32),
    nightInk: Color(0xFFF7F1EA),
    nightMuted: Color(0x99F7F1EA),
    accentNight: Color(0xFFD9A441),
    accentNightSoft: Color(0x2ED9A441),
    onAccentNight: Color(0xFF2D3A32),
  );

  static const _cellarModernGold = GlasColors(
    canvas: Color(0xFFE8CDBD),
    paper: Color(0xFFF7F1EA),
    card: Color(0xFFFFFCF7),
    ink: Color(0xFF2D3A32),
    muted: Color(0xFF5F6B62),
    line: Color(0x212D3A32),
    accent: Color(0xFFA9761C),
    accentSoft: Color(0x33D9A441),
    onAccent: Color(0xFF2D3A32),
    night: Color(0xFF2D3A32),
    nightInk: Color(0xFFF7F1EA),
    nightMuted: Color(0x99F7F1EA),
    accentNight: Color(0xFFD9A441),
    accentNightSoft: Color(0x2ED9A441),
    onAccentNight: Color(0xFF2D3A32),
  );

  static const _cellar = GlasColors(
    canvas: Color(0xFF1F2922),
    paper: Color(0xFF25302A),
    card: Color(0xFF2D3A32),
    ink: Color(0xFFF7F1EA),
    muted: Color(0xFFA3AFA6),
    line: Color(0x24F7F1EA),
    accent: Color(0xFFD9A441),
    accentSoft: Color(0x2ED9A441),
    onAccent: Color(0xFF2D3A32),
    night: Color(0xFF1A231D),
    nightInk: Color(0xFFF7F1EA),
    nightMuted: Color(0x99F7F1EA),
    accentNight: Color(0xFFD9A441),
    accentNightSoft: Color(0x2ED9A441),
    onAccentNight: Color(0xFF2D3A32),
  );

  static GlasColors of(GlasThemeName name) => switch (name) {
        GlasThemeName.cellarModern => _cellarModern,
        GlasThemeName.cellarModernGold => _cellarModernGold,
        GlasThemeName.cellar => _cellar,
      };

  @override
  GlasColors copyWith({
    Color? canvas,
    Color? paper,
    Color? card,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? night,
    Color? nightInk,
    Color? nightMuted,
    Color? accentNight,
    Color? accentNightSoft,
    Color? onAccentNight,
  }) =>
      GlasColors(
        canvas: canvas ?? this.canvas,
        paper: paper ?? this.paper,
        card: card ?? this.card,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        onAccent: onAccent ?? this.onAccent,
        night: night ?? this.night,
        nightInk: nightInk ?? this.nightInk,
        nightMuted: nightMuted ?? this.nightMuted,
        accentNight: accentNight ?? this.accentNight,
        accentNightSoft: accentNightSoft ?? this.accentNightSoft,
        onAccentNight: onAccentNight ?? this.onAccentNight,
      );

  @override
  GlasColors lerp(ThemeExtension<GlasColors>? other, double t) {
    if (other is! GlasColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return GlasColors(
      canvas: mix(canvas, other.canvas),
      paper: mix(paper, other.paper),
      card: mix(card, other.card),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      onAccent: mix(onAccent, other.onAccent),
      night: mix(night, other.night),
      nightInk: mix(nightInk, other.nightInk),
      nightMuted: mix(nightMuted, other.nightMuted),
      accentNight: mix(accentNight, other.accentNight),
      accentNightSoft: mix(accentNightSoft, other.accentNightSoft),
      onAccentNight: mix(onAccentNight, other.onAccentNight),
    );
  }
}

/// Loads every face and weight the app draws with, so the first frame is
/// already set in them. Asking for each style is what starts the load; the
/// files are bundled, so this takes milliseconds.
Future<void> preloadGlasFonts() async {
  GlasType.display(12);
  GlasType.displayItalic(12);
  GlasType.body(12);
  GlasType.body(12, weight: FontWeight.w500);
  GlasType.label(12);
  await GoogleFonts.pendingFonts();
}

/// The three type roles in the design.
///
/// * [display] — Libre Caslon Text, for names, numbers and headlines
/// * body — Public Sans, everything else
/// * [label] — Azeret Mono, the uppercase tracked-out section labels
class GlasType {
  const GlasType._();

  static TextStyle display(double size, {Color? color, double height = 1.15}) =>
      GoogleFonts.libreCaslonText(
        fontSize: size,
        height: height,
        color: color,
        letterSpacing: 0.01 * size / size,
      );

  static TextStyle displayItalic(double size, {Color? color}) =>
      GoogleFonts.libreCaslonText(
        fontSize: size,
        height: 1.45,
        fontStyle: FontStyle.italic,
        color: color,
      );

  static TextStyle body(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 1.4,
  }) =>
      GoogleFonts.publicSans(
        fontSize: size,
        height: height,
        fontWeight: weight,
        color: color,
      );

  /// The small uppercase monospace labels that head every section.
  static TextStyle label(double size, {Color? color, double tracking = 0.16}) =>
      GoogleFonts.azeretMono(
        fontSize: size,
        color: color,
        letterSpacing: size * tracking,
      );

  /// Codes and numbers that want the monospace face without the uppercasing.
  static TextStyle mono(double size, {Color? color, double tracking = 0}) =>
      GoogleFonts.azeretMono(
        fontSize: size,
        color: color,
        letterSpacing: size * tracking,
      );
}

ThemeData buildGlasTheme(GlasColors c) {
  final isDark = ThemeData.estimateBrightnessForColor(c.paper) == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: c.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.paper,
      onSurface: c.ink,
    ),
    textTheme: GoogleFonts.publicSansTextTheme().apply(
      bodyColor: c.ink,
      displayColor: c.ink,
    ),
    splashFactory: InkSparkle.splashFactory,
    extensions: [c],
  );
}

extension GlasColorsContext on BuildContext {
  GlasColors get glas => Theme.of(this).extension<GlasColors>()!;
}
