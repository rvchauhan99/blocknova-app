import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'bootstrap/auth_bootstrap.dart';
import 'bootstrap/crashlytics_bootstrap.dart';
import 'platform_services/remote_config/blocknova_remote_config.dart';
import 'platform_services/analytics/analytics_scope.dart';
import 'platform_services/analytics/analytics_service.dart';
import 'platform_services/analytics/firebase_analytics_service.dart';
import 'screens/splash_screen.dart';
import 'theme/blastnova_brand.dart';
import 'theme/blastnova_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final analytics = await _initializeServices();
  runApp(BlockNovaApp(analytics: analytics));
}

Future<AnalyticsService> _initializeServices() async {
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
    configureFirebaseCrashlytics();
    await ensureAnonymousAuth();
    await BlocknovaRemoteConfig.initialize();
  } catch (e) {
    debugPrint('Firebase initialization skipped during bootstrap: $e');
  }

  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds initialization skipped during bootstrap: $e');
    }
  }

  return firebaseReady ? FirebaseAnalyticsService() : DebugAnalyticsService();
}

class BlockNovaApp extends StatefulWidget {
  const BlockNovaApp({super.key, required this.analytics});

  final AnalyticsService analytics;

  @override
  State<BlockNovaApp> createState() => _BlockNovaAppState();
}

class _BlockNovaAppState extends State<BlockNovaApp> with WidgetsBindingObserver {
  bool _loggedAppOpen = false;
  DateTime? _sessionAnchor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final analytics = widget.analytics;
    if (state == AppLifecycleState.resumed) {
      if (!_loggedAppOpen) {
        _loggedAppOpen = true;
        unawaited(analytics.logEvent('app_open'));
      }
      if (_sessionAnchor == null) {
        _sessionAnchor = DateTime.now();
        unawaited(BlocknovaRemoteConfig.refresh());
        unawaited(
          analytics.logEvent(
            'session_start',
            parameters: <String, Object?>{
              'experiment_ad_pacing': BlocknovaRemoteConfig.experimentAdPacingVariant,
            },
          ),
        );
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _endForegroundSession(analytics);
    }
  }

  void _endForegroundSession(AnalyticsService analytics) {
    final anchor = _sessionAnchor;
    if (anchor == null) {
      return;
    }
    final sec = DateTime.now().difference(anchor).inSeconds;
    _sessionAnchor = null;
    unawaited(
      analytics.logEvent('session_end', parameters: <String, Object?>{'duration_sec': sec}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: BlastNovaBrand.kStoreTitle,
      debugShowCheckedModeBanner: false,
      theme: buildBlastNovaTheme(),
      builder: (context, child) {
        return AnalyticsScope(
          analytics: widget.analytics,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
