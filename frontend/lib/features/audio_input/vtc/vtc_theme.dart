import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Visual language for the Voice Training Center.
///
/// Intentionally local to the VTC feature: the rest of the app keeps using
/// [AppTheme] and is unaffected by these colours.
class VtcPalette {
  VtcPalette._();

  // Deep midnight navy — page base and glass panels.
  static const Color midnight = Color(0xFF070C24);
  static const Color navyDeep = Color(0xFF0A1030);
  static const Color royalBlue = Color(0xFF12205A);

  // Violet-blue midtones used by the sky and panel glow.
  static const Color violet = Color(0xFF2A1E5C);
  static const Color violetSoft = Color(0xFF3A2A7A);

  // Luminous electric blue accents.
  static const Color electric = Color(0xFF4DA3FF);
  static const Color electricBright = Color(0xFF7CC6FF);

  // Champagne / gold.
  static const Color gold = Color(0xFFE3C27E);
  static const Color goldDeep = Color(0xFFC9A257);
  static const Color goldLight = Color(0xFFF4DFAE);

  // Warm ivory typography.
  static const Color ivory = Color(0xFFF6F0E3);
  static const Color ivoryDim = Color(0xFFCFC7B8);

  // Sunset horizon warmth.
  static const Color sunset = Color(0xFFE98F5A);
  static const Color sunCore = Color(0xFFFFD9A0);

  static const Color danger = Color(0xFFFF8A80);
  static const Color success = Color(0xFF9BE7C4);

  // -- Virtual Recording specification tokens -------------------------------
  // Exact values from the implementation brief. Kept in the same palette so
  // the new page extends the VTC look instead of introducing a second theme.
  static const Color appBg = Color(0xFF050B20);
  static const Color headerBg = Color(0xFF080D2B);
  static const Color sidebarBg = Color(0xFF070D28);
  static const Color workspace = Color(0xFF071632);
  static const Color card = Color(0xFF091B3B);
  static const Color input = Color(0xFF0D2147);
  static const Color elevated = Color(0xFF101F4A);
  static const Color border = Color(0xFF123C78);
  static const Color borderActive = Color(0xFF1768B7);
  static const Color divider = Color(0xFF1A3159);
  static const Color focus = Color(0xFF58D9FF);
  static const Color penroseViolet = Color(0xFF5126D8);
  static const Color brightViolet = Color(0xFF693BFF);
  static const Color indigo = Color(0xFF243FDB);
  static const Color cyan = Color(0xFF00D8F5);
  static const Color blue = Color(0xFF258BFF);
  static const Color textPrimary = Color(0xFFF4F7FF);
  static const Color textSecondary = Color(0xFFB9C8E5);
  static const Color textMuted = Color(0xFF8296BC);
  static const Color recording = Color(0xFFF52F67);
  static const Color successBright = Color(0xFF00E5A0);
  static const Color warning = Color(0xFFFFC857);
  static const Color error = Color(0xFFFF526D);
  static const Color disabled = Color(0xFF52617E);
  static const Color info = Color(0xFF60B9FF);

  /// Indigo-to-violet fill for primary actions.
  static const LinearGradient actionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo, penroseViolet],
  );

  /// Green/teal fill reserved for "this meeting is live" status, never for a
  /// recording state.
  static const LinearGradient liveGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [successBright, Color(0xFF00C2B2)],
  );

  /// Gold gradient used by the primary call to action and the active nav pill.
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDeep],
  );

  /// Tint for glass panels: dark blue/violet with a luminous top edge.
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x3D2A3F7A), Color(0x2E14204F), Color(0x24100E33)],
  );

  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xD9070C24), Color(0xE6091233), Color(0xF2070A1C)],
  );

  /// Backdrop scrim so foreground text always clears contrast requirements.
  static const LinearGradient headerScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xCC05081C), Color(0x8A05081C), Color(0x0005081C)],
  );
}

/// Shared type ramp for the VTC. The app bundles only a Latin UI font, so a
/// classical feel is achieved with letter-spacing and weight rather than a
/// second font family we do not ship.
class VtcType {
  VtcType._();

  static const List<String> fallback = ['DejaVuSans'];

  /// Big centre hero: "Train Your Voice / with Penrose".
  static TextStyle hero(BuildContext context) => TextStyle(
        fontSize: 54,
        height: 1.05,
        fontWeight: FontWeight.w300,
        letterSpacing: 0.2,
        color: VtcPalette.ivory,
        fontFamilyFallback: fallback,
        shadows: const [
          Shadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 6)),
          Shadow(color: Color(0x557FC6FF), blurRadius: 40, offset: Offset(0, 0)),
        ],
      );

  /// Small-caps eyebrow such as the "Speak • Synthesize • Be Heard" line.
  static TextStyle subtitle(BuildContext context) => TextStyle(
        fontSize: 15,
        letterSpacing: 5.5,
        fontWeight: FontWeight.w300,
        color: VtcPalette.ivoryDim,
        fontFamilyFallback: fallback,
      );

  /// Serif-feel section heading inside the glass card.
  static TextStyle sectionHeading(BuildContext context) => TextStyle(
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        color: VtcPalette.ivory,
        fontFamilyFallback: fallback,
      );

  static TextStyle body(BuildContext context) =>
      TextStyle(fontSize: 15.5, height: 1.45, color: VtcPalette.ivoryDim, fontFamilyFallback: fallback);

  static TextStyle bodyIvory(BuildContext context) =>
      TextStyle(fontSize: 15.5, height: 1.45, color: VtcPalette.ivory, fontFamilyFallback: fallback);

  static TextStyle brand(BuildContext context) => TextStyle(
        fontSize: 26,
        letterSpacing: 7,
        fontWeight: FontWeight.w600,
        color: VtcPalette.ivory,
        fontFamilyFallback: fallback,
        shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 14, offset: Offset(0, 3))],
      );

  static TextStyle brandSub(BuildContext context) => TextStyle(
        fontSize: 10.5,
        letterSpacing: 3.4,
        fontWeight: FontWeight.w400,
        color: VtcPalette.gold,
        fontFamilyFallback: fallback,
      );

  static TextStyle navItem(BuildContext context) =>
      TextStyle(fontSize: 15.5, letterSpacing: 0.4, fontWeight: FontWeight.w500, fontFamilyFallback: fallback);

  /// Italic decorative line such as "Better Voice / Brighter You".
  static TextStyle flourish(BuildContext context) => TextStyle(
        fontSize: 17,
        height: 1.35,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w300,
        color: VtcPalette.ivory,
        fontFamilyFallback: fallback,
        shadows: const [Shadow(color: Color(0x88000000), blurRadius: 12, offset: Offset(0, 3))],
      );
}

/// Thin gold rule used under flourishes and above buttons.
class GoldRule extends StatelessWidget {
  const GoldRule({super.key, this.width = 72, this.height = 1.4});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: LinearGradient(
            colors: [
              VtcPalette.gold.withValues(alpha: 0.0),
              VtcPalette.goldLight,
              VtcPalette.gold.withValues(alpha: 0.0)
            ],
          ),
        ),
      );
}

/// Translucent, blurred panel with a luminous border. Used for every surface
/// that sits over the scenic backdrop.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 22,
    this.blur = 18,
    this.borderColor,
    this.gradient,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final Color? borderColor;
  final Gradient? gradient;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: gradient ?? VtcPalette.glassGradient,
        border: Border.all(color: borderColor ?? VtcPalette.electric.withValues(alpha: 0.34), width: 1.1),
        boxShadow: [
          BoxShadow(color: const Color(0x66000000), blurRadius: 40, offset: const Offset(0, 18)),
          BoxShadow(color: VtcPalette.electric.withValues(alpha: 0.10), blurRadius: 26, spreadRadius: -6),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
