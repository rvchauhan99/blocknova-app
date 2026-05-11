import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'analytics_param_sanitizer.dart';
import 'analytics_service.dart';

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    final transportName = firebaseTransportEventName(name);
    try {
      if (name == 'screen_view') {
        final sanitized = sanitizeAnalyticsParameters(parameters);
        final screenName = sanitized.remove('screen_name')?.toString();
        await _analytics.logScreenView(
          screenName: screenName,
          parameters: sanitized.isEmpty ? null : Map<String, Object>.from(sanitized),
        );
        return;
      }

      final sanitized = sanitizeAnalyticsParameters(parameters);
      await _analytics.logEvent(
        name: transportName,
        parameters: sanitized.isEmpty ? null : sanitized,
      );
    } catch (e, st) {
      debugPrint('[analytics] logEvent failed ($name -> $transportName): $e\n$st');
    }
  }
}
