import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand accents; raster artwork retains its original colours.
abstract final class SamuderaColors {
  static const blue = Color(0xFF009FE3);
  static const green = Color(0xFF8CC63F);
  static const orange = Color(0xFFF7941D);
}

ThemeData samuderaTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xFF121212) : Colors.white;
  final foreground = dark ? Colors.white : const Color(0xFF202020);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: SamuderaColors.blue,
        brightness: brightness,
      ).copyWith(
        primary: SamuderaColors.blue,
        onPrimary: Colors.black,
        primaryContainer: SamuderaColors.blue.withValues(alpha: .18),
        onPrimaryContainer: foreground,
        secondary: SamuderaColors.green,
        onSecondary: Colors.black,
        secondaryContainer: SamuderaColors.green.withValues(alpha: .18),
        onSecondaryContainer: foreground,
        tertiary: SamuderaColors.orange,
        onTertiary: Colors.black,
        tertiaryContainer: SamuderaColors.orange.withValues(alpha: .18),
        onTertiaryContainer: foreground,
        error: SamuderaColors.orange,
        onError: Colors.black,
        errorContainer: SamuderaColors.orange.withValues(alpha: .18),
        onErrorContainer: foreground,
        surface: surface,
        onSurface: foreground,
        onSurfaceVariant: dark ? Colors.white70 : Colors.black87,
        surfaceTint: Colors.transparent,
        surfaceDim: dark ? const Color(0xFF101010) : const Color(0xFFE0E0E0),
        surfaceBright: dark ? const Color(0xFF383838) : Colors.white,
        surfaceContainerLowest: dark ? Colors.black : Colors.white,
        surfaceContainerLow: dark
            ? const Color(0xFF191919)
            : const Color(0xFFFAFAFA),
        surfaceContainer: dark
            ? const Color(0xFF222222)
            : const Color(0xFFF5F5F5),
        surfaceContainerHigh: dark
            ? const Color(0xFF292929)
            : const Color(0xFFEEEEEE),
        surfaceContainerHighest: dark
            ? const Color(0xFF333333)
            : const Color(0xFFE5E5E5),
        outline: Colors.grey,
        outlineVariant: dark ? Colors.white24 : Colors.black26,
        inverseSurface: dark ? Colors.white : const Color(0xFF202020),
        onInverseSurface: dark ? Colors.black : Colors.white,
        inversePrimary: SamuderaColors.blue,
        primaryFixed: SamuderaColors.blue,
        primaryFixedDim: SamuderaColors.blue,
        onPrimaryFixed: Colors.black,
        onPrimaryFixedVariant: Colors.black87,
        secondaryFixed: SamuderaColors.green,
        secondaryFixedDim: SamuderaColors.green,
        onSecondaryFixed: Colors.black,
        onSecondaryFixedVariant: Colors.black87,
        tertiaryFixed: SamuderaColors.orange,
        tertiaryFixedDim: SamuderaColors.orange,
        onTertiaryFixed: Colors.black,
        onTertiaryFixedVariant: Colors.black87,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: SamuderaColors.blue,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}
