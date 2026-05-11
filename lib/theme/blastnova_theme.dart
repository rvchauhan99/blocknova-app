import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'arcade_shell_theme.dart';

ThemeData buildBlastNovaTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final body = GoogleFonts.exo2TextTheme(base.textTheme);
  final orbitron = GoogleFonts.orbitronTextTheme(base.textTheme);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ArcadeShellTheme.bgNavy,
    colorScheme: ColorScheme.dark(
      primary: ArcadeShellTheme.glowCyan,
      onPrimary: Colors.black,
      secondary: ArcadeShellTheme.neonPink,
      surface: const Color(0xFF12182C),
      onSurface: Colors.white,
    ),
    textTheme: body.copyWith(
      displayLarge: orbitron.displayLarge?.copyWith(fontWeight: FontWeight.w900),
      headlineMedium: orbitron.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: orbitron.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: orbitron.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.orbitron(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: Colors.white,
      ),
    ),
  );
}
