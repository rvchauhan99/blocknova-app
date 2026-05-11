import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/arcade_shell_theme.dart';

/// Layered gradient + soft drifting orbs + capped particle field (RepaintBoundary).
class ArcadeAmbientBackground extends StatefulWidget {
  const ArcadeAmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<ArcadeAmbientBackground> createState() => _ArcadeAmbientBackgroundState();
}

class _ArcadeAmbientBackgroundState extends State<ArcadeAmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _ArcadeAmbientPainter(t: _controller.value),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _ArcadeAmbientPainter extends CustomPainter {
  _ArcadeAmbientPainter({required this.t});

  final double t;

  static const int _particleCap = 45;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final drift = t * math.pi * 2;
    final base = Paint()
      ..shader = LinearGradient(
        begin: ArcadeShellTheme.ambientBegin,
        end: ArcadeShellTheme.ambientEnd,
        stops: const [0.0, 0.35, 0.72, 1.0],
        colors: ArcadeShellTheme.ambientGradientStops,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, base);

    final pinkGlow = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.3 + 0.15 * math.sin(drift), -0.4 + 0.1 * math.cos(drift * 0.9)),
        radius: 1.15,
        colors: [
          ArcadeShellTheme.bgNeonPinkGlow,
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.85));
    canvas.drawRect(Offset.zero & size, pinkGlow);

    void drawOrb(double cx, double cy, double r, Color c) {
      final p = Paint()
        ..shader = RadialGradient(
          colors: [c, const Color(0x00000000)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, p);
    }

    final w = size.width;
    final h = size.height;
    drawOrb(
      w * (0.15 + 0.08 * math.sin(drift * 1.1)),
      h * (0.22 + 0.06 * math.cos(drift * 0.85)),
      w * 0.42,
      ArcadeShellTheme.orbCyan,
    );
    drawOrb(
      w * (0.88 + 0.05 * math.cos(drift * 0.95)),
      h * (0.55 + 0.07 * math.sin(drift)),
      w * 0.38,
      ArcadeShellTheme.orbMagenta,
    );
    drawOrb(
      w * (0.5 + 0.12 * math.sin(drift * 0.7)),
      h * (0.82 + 0.04 * math.cos(drift * 1.2)),
      w * 0.35,
      ArcadeShellTheme.orbPink,
    );

    final particlePaint = Paint()..style = PaintingStyle.fill;
    final rnd = math.Random(7);
    for (var i = 0; i < _particleCap; i++) {
      final u = rnd.nextDouble();
      final v = rnd.nextDouble();
      final phase = drift * (0.4 + rnd.nextDouble() * 1.2) + i * 0.31;
      final px = (u * w + math.sin(phase) * 18) % (w + 20) - 10;
      final py = (v * h + math.cos(phase * 0.9) * 18 + t * h * 0.12) % (h + 16) - 8;
      final alpha = (0.15 + 0.25 * (0.5 + 0.5 * math.sin(phase + drift * math.pi))).clamp(0.08, 0.45);
      particlePaint.color = Color.lerp(
        const Color(0xFFFFFFFF),
        ArcadeShellTheme.glowCyan,
        rnd.nextDouble(),
      )!.withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), 1.5 + rnd.nextDouble() * 2.5, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcadeAmbientPainter oldDelegate) => oldDelegate.t != t;
}
