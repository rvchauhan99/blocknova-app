import 'package:flutter/material.dart';

/// Shared neon arcade shell tokens (original art direction; no third-party art).
abstract final class ArcadeShellTheme {
  static const Color bgDeepPurple = Color(0xFF130626);
  static const Color bgNavy = Color(0xFF080D21);
  static const Color bgNeonPinkGlow = Color(0x33FF007F);
  
  static const Color neonPink = Color(0xFFFF007F);
  static const Color electricBlue = Color(0xFF00F0FF);
  static const Color glowCyan = Color(0xFF00E5FF);
  static const Color premiumPurple = Color(0xFFB026FF);
  
  static const Color orbCyan = Color(0x6600E5FF);
  static const Color orbMagenta = Color(0x66E040FB);
  static const Color orbPink = Color(0x55FF4081);

  static const List<Color> ambientGradientStops = <Color>[
    Color(0xFF200F3E),
    Color(0xFF10132B),
    Color(0xFF080C1A),
    Color(0xFF050812),
  ];

  static const Alignment ambientBegin = Alignment(-0.85, -1.2);
  static const Alignment ambientEnd = Alignment(0.9, 1.2);

  /// Base for large hero titles; combine with `GoogleFonts.orbitron` where used.
  static const TextStyle titleStyle = TextStyle(
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
    color: Colors.white,
  );
}
