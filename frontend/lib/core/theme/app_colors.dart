import 'dart:ui';

class AppColors {
  AppColors._();

  // ── Surfaces ──
  static const background = Color(0xFF0A0A14);
  static const surface = Color(0xFF10101D);
  static const surfaceElevated = Color(0xFF17172A);
  static const surfaceHighest = Color(0xFF1E1E32);

  // ── Purple palette ──
  static const primary = Color(0xFF8B5CF6);
  static const primaryLight = Color(0xFFA78BFA);
  static const primaryDark = Color(0xFF7C3AED);
  static const primaryMuted = Color(0xFF6D28D9);
  static const primaryGlow = Color(0x338B5CF6);

  // ── Text ──
  static const textPrimary = Color(0xFFF5F3FF);
  static const textSecondary = Color(0xFFC4C2D8);
  static const textMuted = Color(0xFF85839A);
  static const textOnPrimary = Color(0xFFFFFFFF);

  // ── Semantic ──
  static const success = Color(0xFF78D65C);
  static const successMuted = Color(0x2278D65C);
  static const warning = Color(0xFFF4C95D);
  static const warningMuted = Color(0x22F4C95D);
  static const error = Color(0xFFFF4D67);
  static const errorMuted = Color(0x22FF4D67);
  static const info = Color(0xFF60A5FA);
  static const infoMuted = Color(0x2260A5FA);

  // ── Accents ──
  static const accent = Color(0xFF818CF8);
  static const lavender = Color(0xFFA78BFA);
  static const teal = Color(0xFF2DD4BF);

  // ── Borders & Dividers ──
  static const border = Color(0xFF2A2A3E);
  static const borderLight = Color(0xFF1E1E32);
  static const divider = Color(0xFF1E1E32);

  // ── Card presets ──
  static const card = Color(0xFF10101D);
  static const cardHover = Color(0xFF17172A);

  // ── Legacy aliases (keep existing references compiling) ──
  static const primaryDarkOld = primaryDark;
  static const secondary = Color(0xFFC084FC);
  static const secondaryLight = Color(0xFFE9D5FF);
}
