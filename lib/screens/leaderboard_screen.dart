import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bootstrap/auth_bootstrap.dart';
import '../platform_services/analytics/analytics_scope.dart';
import '../platform_services/backend/blocknova_backend_service.dart';
import '../theme/blastnova_brand.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final BlocknovaBackendService _backend = BlocknovaBackendService();
  Future<List<LeaderboardEntryDto>>? _future;
  bool _loggedView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loggedView) {
        return;
      }
      _loggedView = true;
      final analytics = AnalyticsScope.maybeOf(context);
      if (analytics != null) {
        unawaited(analytics.logEvent('leaderboard_view'));
      }
    });
    _reload();
  }

  void _reload() {
    if (!Firebase.apps.isNotEmpty || !_backend.isAvailable) {
      setState(() {
        _future = Future<List<LeaderboardEntryDto>>.value(<LeaderboardEntryDto>[]);
      });
      return;
    }
    setState(() {
      _future = () async {
        await ensureAnonymousAuth();
        try {
          return await _backend.getLeaderboard(limit: 25);
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint('getLeaderboard failed: $e\n$st');
          }
          rethrow;
        }
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              BlastNovaBrand.kBrandWordmark,
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.white70,
              ),
            ),
            Text(
              'Leaderboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Endless',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LeaderboardEntryDto>>(
              future: _future,
              builder: (context, snapshot) {
                if (!Firebase.apps.isNotEmpty || !_backend.isAvailable) {
                  return const Center(child: Text('Firebase not configured.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final entries = snapshot.data ?? <LeaderboardEntryDto>[];
                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No scores on the server yet.\n\n'
                        'Scores are sent when you tap END RUN after a game (or when you leave the game screen). '
                        'Play a run, then tap END RUN so your score can appear here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.35),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final name = e.displayName ?? e.uid;
                    return ListTile(
                      leading: CircleAvatar(child: Text('${e.rank}')),
                      title: Text(name),
                      subtitle: Text(e.uid),
                      trailing: Text('${e.score}', style: Theme.of(context).textTheme.titleMedium),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
