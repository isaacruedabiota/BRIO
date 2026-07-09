import 'package:flutter/material.dart';

/// BRIO color tokens with light/dark theme support.
///
/// Brand, semantic and macro colors are identical in both modes (kept `const`).
/// Only background and text tokens change with the mode: they are mutable and
/// reassigned by [applyBrightness], so existing call sites keep working and the
/// app can switch theme at runtime.
abstract final class BrioColors {
  // Brand (blue) — same in light/dark.
  static const blue        = Color(0xFF329FFC);
  static const blueDeep    = Color(0xFF1B6FD0);
  static const blueBright  = Color(0xFF7FC4FF);

  static const green       = blue;                // brand alias (legacy name)
  static const greenDeep   = Color(0xFF1B6FD0);
  static const greenMedium = Color(0xFF2A8AE8);
  static const greenLight  = Color(0xFF5AB0FF);
  static const greenBright = Color(0xFF7FC4FF);
  static const primary     = blue;

  static const gradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end:   Alignment.topRight,
    colors: [Color(0xFF1B6FD0), Color(0xFF329FFC), Color(0xFF7FC4FF)],
    stops:  [0.0, 0.55, 1.0],
  );

  // Semantic / macro colors — same in light/dark.
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF5A623);
  static const error   = Color(0xFFFF4D4D);
  static const info    = Color(0xFF329FFC);

  static const protein = Color(0xFFE11D48);   // crimson
  static const carbs   = Color(0xFFD97706);   // amber
  static const fat     = Color(0xFF0D9488);   // teal

  static const textInverse = Color(0xFFFFFFFF);   // text on blue/buttons

  // Theme-dependent tokens (mutable). Initialized to light; reassigned by
  // [applyBrightness].
  static Color bgBase       = const Color(0xFFFFFFFF);
  static Color bgSurface    = const Color(0xFFF4F6FA);
  static Color bgElevated   = const Color(0xFFEBEEF4);
  static Color bgCard       = const Color(0xFFF6F8FB);
  static Color border       = const Color(0xFFE4E9F0);
  static Color textPrimary  = const Color(0xFF1B2A4A);
  static Color textSecondary= const Color(0xFF6B7488);
  static Color textTertiary = const Color(0xFFA7AFBF);

  static Brightness brightness = Brightness.light;

  /// Applies the background/text palette for the given mode.
  static void applyBrightness(Brightness b) {
    brightness = b;
    if (b == Brightness.dark) {
      bgBase        = const Color(0xFF0F0F14);
      bgSurface     = const Color(0xFF16161F);
      bgElevated    = const Color(0xFF242433);
      bgCard        = const Color(0xFF1A1A24);
      border        = const Color(0xFF2C2C3D);
      textPrimary   = const Color(0xFFFFFFFF);
      textSecondary = const Color(0xFF9A9AAE);
      textTertiary  = const Color(0xFF55556A);
    } else {
      bgBase        = const Color(0xFFFFFFFF);
      bgSurface     = const Color(0xFFF4F6FA);
      bgElevated    = const Color(0xFFEBEEF4);
      bgCard        = const Color(0xFFF6F8FB);
      border        = const Color(0xFFE4E9F0);
      textPrimary   = const Color(0xFF1B2A4A);
      textSecondary = const Color(0xFF6B7488);
      textTertiary  = const Color(0xFFA7AFBF);
    }
  }
}
