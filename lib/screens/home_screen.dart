import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../platform_services/analytics/analytics_scope.dart';
import '../platform_services/personal_best_store.dart';
import '../theme/arcade_shell_theme.dart';
import '../theme/blastnova_brand.dart';
import '../widgets/arcade_ambient_background.dart';
import 'game_placeholder_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _personalBest = 0;
  bool _loadingBest = true;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
    unawaited(_loadBest());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final analytics = AnalyticsScope.maybeOf(context);
      if (analytics != null) {
        unawaited(
          analytics.logEvent('screen_view', parameters: <String, Object?>{'screen_name': 'home'}),
        );
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final v = await PersonalBestStore.read();
    if (!mounted) {
      return;
    }
    setState(() {
      _personalBest = v;
      _loadingBest = false;
    });
  }

  Future<void> _openPlay() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const GamePlaceholderScreen(),
      ),
    );
    await _loadBest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArcadeShellTheme.bgNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: ArcadeAmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 1),
                Center(
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, _) {
                      return ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: const [
                              Colors.white,
                              ArcadeShellTheme.glowCyan,
                              ArcadeShellTheme.neonPink,
                              Colors.white,
                            ],
                            stops: const [0.0, 0.4, 0.6, 1.0],
                            begin: Alignment(-2.0 + 4.0 * _animController.value, -1),
                            end: Alignment(0.0 + 4.0 * _animController.value, 1),
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcIn,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            BlastNovaBrand.kBrandWordmark.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.orbitron(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: ArcadeShellTheme.glowCyan.withValues(alpha: 0.8),
                                  blurRadius: 25,
                                ),
                                Shadow(
                                  color: ArcadeShellTheme.neonPink.withValues(alpha: 0.5),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  BlastNovaBrand.kTaglineShort,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.white.withValues(alpha: 0.05),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD60A), size: 28),
                          const SizedBox(width: 12),
                          Text(
                            _loadingBest ? '---' : 'BEST SCORE: $_personalBest',
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                GestureDetector(
                  onTap: _openPlay,
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final pulse = 1.0 + 0.04 * math.sin(_animController.value * math.pi * 2);
                      return Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                ArcadeShellTheme.premiumPurple,
                                ArcadeShellTheme.neonPink,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ArcadeShellTheme.neonPink.withValues(alpha: 0.4 * pulse),
                                blurRadius: 35,
                                spreadRadius: 2,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: ArcadeShellTheme.glowCyan.withValues(alpha: 0.2 * pulse),
                                blurRadius: 20,
                                spreadRadius: -5,
                                offset: const Offset(0, -8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'PLAY',
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 10,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    offset: const Offset(0, 3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: () {
                    unawaited(
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const LeaderboardScreen(),
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: ArcadeShellTheme.glowCyan,
                    side: BorderSide(color: ArcadeShellTheme.glowCyan.withValues(alpha: 0.5), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: ArcadeShellTheme.glowCyan.withValues(alpha: 0.05),
                  ),
                  child: Text('LEADERBOARDS', style: GoogleFonts.orbitron(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 2)),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
