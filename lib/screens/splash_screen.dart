import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../platform_services/asset_audio_service.dart';
import '../platform_services/audio_service.dart';
import '../theme/arcade_shell_theme.dart';
import '../theme/blastnova_brand.dart';
import '../widgets/arcade_ambient_background.dart';
import 'home_screen.dart';

/// Short branded intro before [HomeScreen]. Original visuals only (no third-party art).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.audioService});

  final AudioService? audioService;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _bounce;
  late final AnimationController _glow;
  late final AnimationController _cubes;
  late final AnimationController _scale;
  late final AnimationController _shimmer;
  late final Animation<double> _scaleA;
  late final Animation<double> _bounceY;
  late final Animation<double> _glowA;
  AudioService? _ownedAudio;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _cubes = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
    _scale = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    _bounceY = Tween<double>(begin: 0, end: -14).animate(
      CurvedAnimation(parent: _bounce, curve: Curves.easeInOut),
    );
    _glowA = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _glow, curve: Curves.easeInOut),
    );
    _scaleA = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _scale, curve: Curves.elasticOut),
    );

    final audio = widget.audioService ?? AssetAudioService();
    if (widget.audioService == null) {
      _ownedAudio = audio;
    }
    unawaited(audio.onSplashIntro());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (ctx, anim, secondaryAnim) => const HomeScreen(),
            transitionDuration: const Duration(milliseconds: 420),
            transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _bounce.dispose();
    _glow.dispose();
    _cubes.dispose();
    _scale.dispose();
    _shimmer.dispose();
    final o = _ownedAudio;
    if (o != null) {
      unawaited(o.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcadeShellTheme.bgNavy,
      body: ArcadeAmbientBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_bounce, _glow, _cubes, _shimmer]),
            builder: (context, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _FloatingCubesPainter(t: _cubes.value),
                    child: const SizedBox.expand(),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: Offset(0, _bounceY.value),
                          child: Transform.scale(
                            scale: _scaleA.value,
                            child: _logoMark(_glowA.value),
                          ),
                        ),
                        const SizedBox(height: 28),
                        RepaintBoundary(
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: const [
                                  Colors.white,
                                  ArcadeShellTheme.glowCyan,
                                  ArcadeShellTheme.neonPink,
                                  Colors.white,
                                ],
                                stops: const [0.0, 0.42, 0.58, 1.0],
                                begin: Alignment(-1.6 + 3.2 * _shimmer.value, -0.4),
                                end: Alignment(-0.2 + 3.2 * _shimmer.value, 0.9),
                              ).createShader(bounds);
                            },
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                BlastNovaBrand.kBrandWordmark,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.orbitron(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: _glowA.value * 0.85),
                                      blurRadius: 20,
                                    ),
                                    Shadow(
                                      color: const Color(0xFFE040FB).withValues(alpha: _glowA.value * 0.5),
                                      blurRadius: 28,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          BlastNovaBrand.kSplashTagline.toUpperCase(),
                          style: GoogleFonts.orbitron(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                            letterSpacing: 2.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              color: const Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _logoMark(double glow) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3949AB), Color(0xFFE040FB)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.25 + glow * 0.25),
            blurRadius: 28 + glow * 12,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: ArcadeShellTheme.premiumPurple.withValues(alpha: 0.2 + glow * 0.2),
            blurRadius: 36 + glow * 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.grid_4x4_rounded, size: 52, color: Colors.white),
      ),
    );
  }
}

class _FloatingCubesPainter extends CustomPainter {
  _FloatingCubesPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(99);
    for (var i = 0; i < 20; i++) {
      final baseX = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final phase = i * 0.7 + t * math.pi * 2;
      final x = baseX + math.sin(phase) * 22;
      final y = baseY + math.cos(phase * 0.85) * 18;
      final s = 8 + rnd.nextDouble() * 12;

      final baseColor = Color.lerp(
        ArcadeShellTheme.glowCyan,
        ArcadeShellTheme.neonPink,
        rnd.nextDouble(),
      )!;

      final alpha = 0.15 + 0.15 * (0.5 + 0.5 * math.sin(phase));

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: s, height: s),
        const Radius.circular(4),
      );

      final paint = Paint()..color = baseColor.withValues(alpha: alpha);
      canvas.drawRRect(rect, paint);

      final highlight = Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.save();
      canvas.clipRect(Rect.fromCenter(center: Offset(x, y - s * 0.25), width: s, height: s * 0.5));
      canvas.drawRRect(rect, highlight);
      canvas.restore();

      final shadow = Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.save();
      canvas.clipRect(Rect.fromCenter(center: Offset(x, y + s * 0.25), width: s, height: s * 0.5));
      canvas.drawRRect(rect, shadow);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingCubesPainter oldDelegate) => oldDelegate.t != t;
}
