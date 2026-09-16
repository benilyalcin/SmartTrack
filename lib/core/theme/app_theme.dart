import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4),
    BoxShadow(
      color: Color(0x4D000000),
      offset: Offset(0, 7),
      blurRadius: 13,
      spreadRadius: -3,
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFffffff),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF3d5500),
        onPrimary: Color(0xFFffffff),
        primaryContainer: Color(0xFF526e0f),
        onPrimaryContainer: Color(0xFFcdf084),
        secondary: Color(0xFF4a6700),
        onSecondary: Color(0xFFffffff),
        secondaryContainer: Color(0xFFb8f238),
        onSecondaryContainer: Color(0xFF4e6c00),
        tertiary: Color(0xFF3d5500),
        onTertiary: Color(0xFFffffff),
        tertiaryContainer: Color(0xFF506f00),
        onTertiaryContainer: Color(0xFFc9f276),
        error: Color(0xFFba1a1a),
        onError: Color(0xFFffffff),
        errorContainer: Color(0xFFffdad6),
        onErrorContainer: Color(0xFF93000a),
        surface: Color(0xFFfafaf3),
        onSurface: Color(0xFF1a1c18),
        surfaceContainerHighest: Color(0xFFe3e3dc),
        onSurfaceVariant: Color(0xFF44483a),
        outline: Color(0xFF757968),
        outlineVariant: Color(0xFFc5c8b5),
      ),

      textTheme: GoogleFonts.ibmPlexSansTextTheme(),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: const Color(0xFF1c1c1c),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFb8f238),
        onPrimary: Color(0xFF2a3900),
        primaryContainer: Color(0xFF3d5500),
        onPrimaryContainer: Color(0xFFcdf084),
        secondary: Color(0xFFcdf084),
        onSecondary: Color(0xFF3a4e00),
        secondaryContainer: Color(0xFF4e6c00),
        onSecondaryContainer: Color(0xFFd7f89a),
        tertiary: Color(0xFFc9f276),
        onTertiary: Color(0xFF334700),
        tertiaryContainer: Color(0xFF506f00),
        onTertiaryContainer: Color(0xFFe4ffb8),
        error: Color(0xFFffb4ab),
        onError: Color(0xFF690005),
        errorContainer: Color(0xFF93000a),
        onErrorContainer: Color(0xFFffdad6),
        surface: Color(0xFF242424),
        onSurface: Color(0xFFe4e4e4),
        surfaceContainerHighest: Color(0xFF3d3d3d),
        onSurfaceVariant: Color(0xFFc6c6c6),
        outline: Color(0xFF919191),
        outlineVariant: Color(0xFF4a4a4a),
      ),
      textTheme: GoogleFonts.ibmPlexSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
    );
  }
}
