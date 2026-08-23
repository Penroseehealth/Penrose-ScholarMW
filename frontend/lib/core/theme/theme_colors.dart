import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_colors_light.dart';

class ThemeColors {
  final Brightness _brightness;
  const ThemeColors._(this._brightness);

  bool get _isDark => _brightness == Brightness.dark;

  Color _dark(Color d, Color l) => _isDark ? d : l;

  // ── Surfaces ──
  Color get background => _dark(AppColors.background, AppColorsLight.background);
  Color get surface => _dark(AppColors.surface, AppColorsLight.surface);
  Color get surfaceElevated => _dark(AppColors.surfaceElevated, AppColorsLight.surfaceElevated);
  Color get surfaceHighest => _dark(AppColors.surfaceHighest, AppColorsLight.surfaceHighest);

  // ── Purple palette ──
  Color get primary => AppColors.primary;
  Color get primaryLight => AppColors.primaryLight;
  Color get primaryDark => AppColors.primaryDark;
  Color get primaryMuted => AppColors.primaryMuted;
  Color get primaryGlow => _dark(AppColors.primaryGlow, AppColorsLight.primaryGlow);

  // ── Text ──
  Color get textPrimary => _dark(AppColors.textPrimary, AppColorsLight.textPrimary);
  Color get textSecondary => _dark(AppColors.textSecondary, AppColorsLight.textSecondary);
  Color get textMuted => _dark(AppColors.textMuted, AppColorsLight.textMuted);
  Color get textOnPrimary => AppColors.textOnPrimary;

  // ── Semantic ──
  Color get success => _dark(AppColors.success, AppColorsLight.success);
  Color get successMuted => _dark(AppColors.successMuted, AppColorsLight.successMuted);
  Color get warning => _dark(AppColors.warning, AppColorsLight.warning);
  Color get warningMuted => _dark(AppColors.warningMuted, AppColorsLight.warningMuted);
  Color get error => _dark(AppColors.error, AppColorsLight.error);
  Color get errorMuted => _dark(AppColors.errorMuted, AppColorsLight.errorMuted);
  Color get info => _dark(AppColors.info, AppColorsLight.info);
  Color get infoMuted => _dark(AppColors.infoMuted, AppColorsLight.infoMuted);

  // ── Accents ──
  Color get accent => _dark(AppColors.accent, AppColorsLight.accent);
  Color get lavender => _dark(AppColors.lavender, AppColorsLight.lavender);
  Color get teal => _dark(AppColors.teal, AppColorsLight.teal);

  // ── Borders & Dividers ──
  Color get border => _dark(AppColors.border, AppColorsLight.border);
  Color get borderLight => _dark(AppColors.borderLight, AppColorsLight.borderLight);
  Color get divider => _dark(AppColors.divider, AppColorsLight.divider);

  // ── Card presets ──
  Color get card => _dark(AppColors.card, AppColorsLight.card);
  Color get cardHover => _dark(AppColors.cardHover, AppColorsLight.cardHover);

  // ── Shimmer ──
  Color get shimmerBase => _dark(AppColors.shimmerBase, AppColorsLight.shimmerBase);
  Color get shimmerHighlight => _dark(AppColors.shimmerHighlight, AppColorsLight.shimmerHighlight);

  // ── Legacy aliases ──
  Color get primaryDarkOld => AppColors.primaryDark;
  Color get secondary => AppColors.secondary;
  Color get secondaryLight => AppColors.secondaryLight;
}

extension ThemeColorsExtension on BuildContext {
  ThemeColors get colors => ThemeColors._(Theme.of(this).brightness);
}
