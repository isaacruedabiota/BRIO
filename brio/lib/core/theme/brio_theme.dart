import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'brio_colors.dart';

abstract final class BrioTheme {
  /// Builds the theme for the given mode. Assumes [BrioColors.applyBrightness]
  /// has already been called with the same `brightness`.
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final scheme = dark
        ? ColorScheme.dark(
            primary:   BrioColors.blue,
            secondary: BrioColors.blueBright,
            surface:   BrioColors.bgSurface,
            error:     BrioColors.error,
            onPrimary: BrioColors.textInverse,
            onSurface: BrioColors.textPrimary,
          )
        : ColorScheme.light(
            primary:   BrioColors.blue,
            secondary: BrioColors.blueBright,
            surface:   BrioColors.bgSurface,
            error:     BrioColors.error,
            onPrimary: BrioColors.textInverse,
            onSurface: BrioColors.textPrimary,
          );

    return ThemeData(
      brightness:   brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: BrioColors.bgBase,
      colorScheme: scheme,

      appBarTheme: AppBarTheme(
        backgroundColor:  BrioColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor:  BrioColors.textPrimary,
        elevation:        0,
        centerTitle:      false,
        titleTextStyle:   GoogleFonts.spaceGrotesk(
          fontSize: 20, fontWeight: FontWeight.w700, color: BrioColors.textPrimary,
        ),
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:      BrioColors.bgSurface,
        selectedItemColor:    BrioColors.blue,
        unselectedItemColor:  BrioColors.textTertiary,
        type:                 BottomNavigationBarType.fixed,
        showSelectedLabels:   true,
        showUnselectedLabels: true,
        selectedLabelStyle:   const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        elevation:            0,
      ),

      cardTheme: CardThemeData(
        color:            BrioColors.bgCard,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: BrioColors.border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:            true,
        fillColor:         BrioColors.bgElevated,
        hintStyle:         TextStyle(color: BrioColors.textTertiary, fontSize: 15),
        contentPadding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border:            _inputBorder(BrioColors.border),
        enabledBorder:     _inputBorder(BrioColors.border),
        focusedBorder:     _inputBorder(BrioColors.blue),
        errorBorder:       _inputBorder(BrioColors.error),
        focusedErrorBorder:_inputBorder(BrioColors.error),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrioColors.blue,
          foregroundColor: BrioColors.textInverse,
          minimumSize:     const Size(double.infinity, 52),
          shape:           const StadiumBorder(),
          textStyle:       GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          elevation:       0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrioColors.textPrimary,
          minimumSize:     const Size(double.infinity, 52),
          shape:           const StadiumBorder(),
          side:            BorderSide(color: BrioColors.border),
          textStyle:       GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrioColors.blue,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: BrioColors.border, thickness: 1, space: 0,
      ),

      textTheme: GoogleFonts.interTextTheme(
        (dark ? ThemeData.dark() : ThemeData.light()).textTheme,
      ).copyWith(
        bodyLarge:  TextStyle(color: BrioColors.textPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: BrioColors.textSecondary, fontSize: 13),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: 1.5),
  );
}
