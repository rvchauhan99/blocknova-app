import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../ads/ads_config.dart';

/// Remote Config keys (mirror in Firebase console and docs).
abstract final class BlocknovaRemoteConfigKeys {
  static const interstitialEveryCompletedRuns = 'ad_interstitial_every_completed_runs';
  static const suppressInterstitialFirstRuns = 'ad_suppress_interstitial_first_runs';
  static const experimentAdPacing = 'experiment_ad_pacing';
}

/// Fetches Remote Config after [Firebase.initializeApp]; safe no-op if Firebase is unavailable.
class BlocknovaRemoteConfig {
  BlocknovaRemoteConfig._();

  static FirebaseRemoteConfig? _instance;

  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      return;
    }
    final rc = FirebaseRemoteConfig.instance;
    _instance = rc;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 12),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
      ),
    );
    await rc.setDefaults(<String, Object>{
      BlocknovaRemoteConfigKeys.interstitialEveryCompletedRuns: AdsConfig.defaults().interstitialEveryCompletedRuns,
      BlocknovaRemoteConfigKeys.suppressInterstitialFirstRuns: AdsConfig.defaults().suppressInterstitialFirstRuns,
      BlocknovaRemoteConfigKeys.experimentAdPacing: 'baseline',
    });
    try {
      await rc.fetchAndActivate();
    } catch (e, st) {
      debugPrint('Remote Config fetch skipped: $e\n$st');
    }
  }

  /// Call after [initialize] (e.g. app resume) to pick up console changes; throttled by [minimumFetchInterval].
  static Future<void> refresh() async {
    final rc = _instance;
    if (rc == null) {
      return;
    }
    try {
      await rc.fetchAndActivate();
    } catch (e, st) {
      debugPrint('Remote Config refresh skipped: $e\n$st');
    }
  }

  static AdsConfig get adsConfig {
    final rc = _instance;
    if (rc == null) {
      return AdsConfig.defaults();
    }
    return AdsConfig.fromRuntime(
      values: <String, Object?>{
        'interstitialEveryCompletedRuns': rc.getInt(BlocknovaRemoteConfigKeys.interstitialEveryCompletedRuns),
        'suppressInterstitialFirstRuns': rc.getInt(BlocknovaRemoteConfigKeys.suppressInterstitialFirstRuns),
      },
    );
  }

  /// A/B or cohort label for analytics (RC string parameter).
  static String get experimentAdPacingVariant {
    final rc = _instance;
    if (rc == null) {
      return 'baseline';
    }
    final v = rc.getString(BlocknovaRemoteConfigKeys.experimentAdPacing).trim();
    return v.isEmpty ? 'baseline' : v;
  }
}
