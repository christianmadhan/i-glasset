import 'package:flutter/material.dart';

import '../theme/glas_theme.dart';

/// The building blocks the design reuses on nearly every screen: the two page
/// surfaces (paper and night), section labels, cards, pill chips, the two
/// button weights, sliders and toggles.

// ---------------------------------------------------------------------------
// page surfaces
// ---------------------------------------------------------------------------

/// A light "paper" screen. Content is inset 22px and starts below the status
/// bar, matching the design's 56px top padding.
class PaperScreen extends StatelessWidget {
  const PaperScreen({
    super.key,
    required this.children,
    this.gap = 22,
    this.padding = const EdgeInsets.fromLTRB(22, 12, 22, 30),
    this.bottomBar,
    this.anchorBottom = false,
  });

  final List<Widget> children;
  final double gap;
  final EdgeInsets padding;
  final Widget? bottomBar;

  /// Stretch the content to at least the height of the viewport, so a
  /// [GlasSpacer] pushes the closing action to the bottom edge.
  final bool anchorBottom;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return _Surface(
      background: c.paper,
      padding: padding,
      gap: gap,
      bottomBar: bottomBar,
      anchorBottom: anchorBottom,
      children: children,
    );
  }
}

/// A dark "night" screen — used for sign-in, joining, and everything that
/// happens while the room is tasting. On these screens the accent turns gold,
/// so the whole subtree is re-themed rather than each widget opting in.
class NightScreen extends StatelessWidget {
  const NightScreen({
    super.key,
    required this.children,
    this.gap = 24,
    this.padding = const EdgeInsets.fromLTRB(22, 12, 22, 30),
    this.anchorBottom = false,
  });

  final List<Widget> children;
  final double gap;
  final EdgeInsets padding;

  /// See [PaperScreen.anchorBottom].
  final bool anchorBottom;

  @override
  Widget build(BuildContext context) {
    final night = context.glas.nightSurface;
    return Theme(
      data: buildGlasTheme(night).copyWith(
        scaffoldBackgroundColor: night.night,
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: night.nightInk,
              displayColor: night.nightInk,
            ),
      ),
      child: Builder(
        builder: (context) => _Surface(
          background: night.night,
          padding: padding,
          gap: gap,
          anchorBottom: anchorBottom,
          children: children,
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.background,
    required this.padding,
    required this.gap,
    required this.children,
    required this.anchorBottom,
    this.bottomBar,
  });

  final Color background;
  final EdgeInsets padding;
  final double gap;
  final List<Widget> children;
  final bool anchorBottom;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: anchorBottom
                  // Fill the viewport so a GlasSpacer can push the closing
                  // action to the bottom, but still scroll rather than
                  // overflow when the content is taller than the screen —
                  // which it is on a small phone with the keyboard up.
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: padding,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight -
                                    padding.vertical)
                                .clamp(0.0, double.infinity),
                          ),
                          child: IntrinsicHeight(child: column),
                        ),
                      ),
                    )
                  : SingleChildScrollView(padding: padding, child: column),
            ),
            ?bottomBar,
          ],
        ),
      ),
    );
  }
}

/// Fills the remaining space so the following widgets sit at the bottom, the
/// way `flex:1` spacers do in the design. Only meaningful inside a
/// non-scrolling column.
class GlasSpacer extends StatelessWidget {
  const GlasSpacer({super.key});

  @override
  Widget build(BuildContext context) => const Spacer();
}

// ---------------------------------------------------------------------------
// text bits
// ---------------------------------------------------------------------------

/// The tracked-out monospace label that heads each section.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color, this.trailing});

  final String text;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: GlasType.label(10.5, color: color ?? context.glas.muted),
    );
    if (trailing == null) return label;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [label, const Spacer(), trailing!],
    );
  }
}

/// A tappable "← Somewhere" link.
class BackLink extends StatelessWidget {
  const BackLink(this.label, {super.key, this.onTap, this.color});

  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GlasTap(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: Text(
          label,
          style: GlasType.body(13.5, color: color ?? context.glas.muted),
        ),
      ),
    );
  }
}

/// Tap target with a consistent, restrained ripple.
class GlasTap extends StatelessWidget {
  const GlasTap({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 12,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// containers
// ---------------------------------------------------------------------------

/// The standard light card: card fill, hairline border, generous radius.
class GlasCard extends StatelessWidget {
  const GlasCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.onTap,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasTap(
      onTap: onTap,
      radius: radius,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? c.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border ?? c.line),
        ),
        child: child,
      ),
    );
  }
}

/// The dark inset panel that appears on light screens — "Næste smagning" on
/// home, the invite code block, the taste-profile summary.
class NightPanel extends StatelessWidget {
  const NightPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasTap(
      onTap: onTap,
      radius: radius,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: c.night,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

/// A hairline-separated stack of rows inside one rounded, clipped frame — the
/// pattern used for leaderboards, fact tables and settings lists.
class GlasList extends StatelessWidget {
  const GlasList({super.key, required this.children, this.radius = 16});

  final List<Widget> children;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Container(
      decoration: BoxDecoration(
        color: c.line,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 1),
            ColoredBox(color: c.card, child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// A square-ish stat tile: big display number over a muted caption.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueSize = 22,
  });

  final String value;
  final String label;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: GlasType.display(valueSize, color: c.ink, height: 1.1)),
          const SizedBox(height: 4),
          Text(label, style: GlasType.body(12, color: c.muted, height: 1.3)),
        ],
      ),
    );
  }
}

/// The round monogram used for people and groups.
class Monogram extends StatelessWidget {
  const Monogram(
    this.initials, {
    super.key,
    this.size = 38,
    this.radius = 12,
    this.background,
    this.foreground,
  });

  final String initials;
  final double size;
  final double radius;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? c.accentSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        initials,
        style: GlasType.display(size * 0.42, color: foreground ?? c.accent),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// controls
// ---------------------------------------------------------------------------

/// The selectable pill. Its selected state draws an inset accent-soft fill with
/// a 1.5px accent border, exactly as the design does.
class GlasChip extends StatelessWidget {
  const GlasChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.dense = false,
    this.radius = 999,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasTap(
      onTap: onTap,
      radius: radius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 13, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: selected ? c.accent : c.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GlasType.body(dense ? 12.5 : 13.5, color: c.ink),
        ),
      ),
    );
  }
}

/// Wrapping row of chips.
class ChipWrap extends StatelessWidget {
  const ChipWrap({super.key, required this.children, this.spacing = 7});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children,
      );
}

enum GlasButtonTone { accent, ink, paper, outline }

/// The 54px primary action that closes most screens.
class GlasButton extends StatelessWidget {
  const GlasButton({
    super.key,
    required this.label,
    this.onTap,
    this.tone = GlasButtonTone.ink,
    this.height = 54,
    this.enabled = true,
    this.leading,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final GlasButtonTone tone;
  final double height;
  final bool enabled;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final (bg, fg, border) = switch (tone) {
      GlasButtonTone.accent => (c.accent, c.onAccent, null),
      GlasButtonTone.ink => (c.ink, c.paper, null),
      GlasButtonTone.paper => (c.nightInk, c.night, null),
      GlasButtonTone.outline => (Colors.transparent, c.ink, c.line),
    };

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GlasTap(
        onTap: enabled ? onTap : null,
        radius: 15,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(15),
            border: border == null ? null : Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Text(
                label,
                style: GlasType.body(16, color: fg, weight: FontWeight.w500),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field styled for paper screens.
class GlasField extends StatelessWidget {
  const GlasField({
    super.key,
    required this.hint,
    this.controller,
    this.label,
    this.obscure = false,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.style,
  });

  final String hint;
  final TextEditingController? controller;
  final String? label;
  final bool obscure;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final field = TextField(
      controller: controller,
      obscureText: obscure,
      minLines: minLines,
      maxLines: obscure ? 1 : maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: style ?? GlasType.body(15, color: c.ink),
      cursorColor: c.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GlasType.body(15, color: c.muted),
        filled: true,
        fillColor: c.card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
    );

    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: GlasType.body(12, color: c.muted)),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}

/// Text field styled for night screens — translucent fill, light text.
class NightField extends StatelessWidget {
  const NightField({
    super.key,
    required this.hint,
    this.controller,
    this.obscure = false,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.style,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final String hint;
  final TextEditingController? controller;
  final bool obscure;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return TextField(
      controller: controller,
      obscureText: obscure,
      minLines: minLines,
      maxLines: obscure ? 1 : maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: style ?? GlasType.body(15, color: c.nightInk),
      cursorColor: c.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GlasType.body(15, color: c.nightMuted),
        filled: true,
        fillColor: c.nightField,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.nightFieldLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.nightFieldLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
    );
  }
}

/// The pill switch used for "Kræv noter", "Gæt om point" and the host toggle.
class GlasSwitch extends StatelessWidget {
  const GlasSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        width: 38,
        height: 20,
        decoration: BoxDecoration(
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(1),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: value ? c.accent : c.muted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row with a title, a subtitle and a switch — the "Format og regler" toggles.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return GlasCard(
      radius: 16,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GlasType.body(14.5, color: c.ink)),
                const SizedBox(height: 3),
                Text(subtitle, style: GlasType.body(12.5, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          GlasSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// The flat drag track used for the score, price, ABV and vintage guesses.
/// Dragging anywhere on the bar sets the value — there is no separate thumb.
class GlasSlider extends StatelessWidget {
  const GlasSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.height = 40,
    this.radius = 11,
    this.track,
    this.overlay,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final double height;
  final double radius;
  final Color? track;

  /// Drawn on top of the fill, e.g. the "1 … 10" end labels on the score bar.
  final Widget? overlay;

  void _setFrom(double dx, double width) {
    final fraction = (dx / width).clamp(0.0, 1.0);
    final raw = min + (max - min) * fraction;
    final snapped = (raw / step).roundToDouble() * step;
    onChanged(double.parse(snapped.clamp(min, max).toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final fraction = max == min ? 0.0 : ((value - min) / (max - min)).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _setFrom(d.localPosition.dx, width),
          onHorizontalDragUpdate: (d) => _setFrom(d.localPosition.dx, width),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: track ?? c.accentSoft,
              borderRadius: BorderRadius.circular(radius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: fraction == 0 ? 0.001 : fraction,
                  child: Container(color: c.accent.withValues(alpha: 0.85)),
                ),
                if (overlay != null) Positioned.fill(child: overlay!),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A labelled horizontal meter — club spend, price accuracy, taste traits.
class MeterRow extends StatelessWidget {
  const MeterRow({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.height = 6,
  });

  final String label;
  final String value;
  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: GlasType.body(12.5, color: c.ink))),
            Text(value, style: GlasType.body(12.5, color: c.muted)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            color: c.accentSoft,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(color: c.accent),
            ),
          ),
        ),
      ],
    );
  }
}

/// The stepper used for "Antal glas" and per-category points.
class Stepper2 extends StatelessWidget {
  const Stepper2({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 12,
    this.size = 38,
    this.valueSize = 21,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double size;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    Widget button(String glyph, int next, bool enabled) => GlasTap(
          onTap: enabled ? () => onChanged(next) : null,
          radius: 999,
          child: Opacity(
            opacity: enabled ? 1 : 0.35,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.line),
              ),
              child: Text(glyph, style: GlasType.body(18, color: c.ink)),
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button('−', value - 1, value > min),
        SizedBox(
          width: valueSize + 14,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: GlasType.display(valueSize, color: c.ink),
          ),
        ),
        button('+', value + 1, value < max),
      ],
    );
  }
}

/// A soft pulsing dot — "waiting for the host", "sent, waiting for the others".
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.size = 7, this.color});

  final double size;
  final Color? color;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.glas.accent;
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// The hatched placeholder standing in for a bottle photo that hasn't been
/// added, or hasn't been downloaded to this device yet.
class HatchedPlaceholder extends StatelessWidget {
  const HatchedPlaceholder({
    super.key,
    this.height,
    this.width,
    this.radius = 16,
    this.caption,
    this.subtitle,
    this.onTap,
    this.onNight = false,
  });

  final double? height;
  final double? width;
  final double radius;
  final String? caption;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool onNight;

  @override
  Widget build(BuildContext context) {
    final c = context.glas;
    final stripe = onNight ? const Color(0x12FFFFFF) : c.ink.withValues(alpha: 0.07);
    final text = onNight ? c.nightMuted : c.muted;

    return GlasTap(
      onTap: onTap,
      radius: radius,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: onNight ? c.nightLine : c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _HatchPainter(stripe),
          child: caption == null
              ? const SizedBox.expand()
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(caption!,
                          style: GlasType.label(11, color: text, tracking: 0.1)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(subtitle!, style: GlasType.body(12.5, color: text)),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6;
    // 135° stripes, 6px on / 6px off, matching the design's repeating gradient.
    for (var x = -size.height; x < size.width + size.height; x += 12) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => oldDelegate.color != color;
}

/// A fade-and-rise entrance, used where the design animates content in.
class RiseIn extends StatelessWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 18,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
