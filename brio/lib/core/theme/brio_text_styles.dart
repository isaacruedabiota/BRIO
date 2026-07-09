import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'brio_colors.dart';

/// BRIO text styles.
///
/// These are **getters**, not fixed `static` fields: each access re-reads the
/// live color from [BrioColors] (textPrimary/textSecondary are mutable and
/// change with the theme). Fixed fields would capture the color of the first
/// theme loaded and text would not update on light/dark switch.
abstract final class BrioTextStyles {
  // Display / titles → Space Grotesk.
  static TextStyle get display => GoogleFonts.spaceGrotesk(
    fontSize: 48, fontWeight: FontWeight.w800, color: BrioColors.textPrimary, height: 1.1,
  );
  static TextStyle get h1 => GoogleFonts.spaceGrotesk(
    fontSize: 36, fontWeight: FontWeight.w700, color: BrioColors.textPrimary, height: 1.15,
  );
  static TextStyle get h2 => GoogleFonts.spaceGrotesk(
    fontSize: 24, fontWeight: FontWeight.w700, color: BrioColors.textPrimary,
  );
  static TextStyle get h3 => GoogleFonts.spaceGrotesk(
    fontSize: 20, fontWeight: FontWeight.w600, color: BrioColors.textPrimary,
  );

  // Body → Inter.
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 17, fontWeight: FontWeight.w400, color: BrioColors.textPrimary,
  );
  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w400, color: BrioColors.textPrimary,
  );
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400, color: BrioColors.textSecondary,
  );
  static TextStyle get label => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: BrioColors.textTertiary,
    letterSpacing: 0.1,
  );

  // Metrics / numbers → DM Mono.
  static TextStyle get metricXL => GoogleFonts.dmMono(
    fontSize: 48, fontWeight: FontWeight.w500, color: BrioColors.textPrimary, height: 1.0,
  );
  static TextStyle get metricLarge => GoogleFonts.dmMono(
    fontSize: 28, fontWeight: FontWeight.w500, color: BrioColors.textPrimary,
  );
  static TextStyle get metric => GoogleFonts.dmMono(
    fontSize: 20, fontWeight: FontWeight.w500, color: BrioColors.textPrimary,
  );
  static TextStyle get metricSmall => GoogleFonts.dmMono(
    fontSize: 13, fontWeight: FontWeight.w400, color: BrioColors.textSecondary,
  );

  // Buttons.
  static TextStyle get button => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w600, color: BrioColors.textInverse,
  );
  static TextStyle get buttonSecondary => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w600, color: BrioColors.textPrimary,
  );
}
