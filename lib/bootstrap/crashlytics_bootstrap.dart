import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Wires framework and async errors to Crashlytics after [Firebase.initializeApp].
///
/// Collection stays **enabled** in release/profile; **disabled** in debug to reduce
/// noise during development (enable in Firebase Console when validating Crashlytics).
void configureFirebaseCrashlytics() {
  if (Firebase.apps.isEmpty) {
    return;
  }
  unawaited(
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode),
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}
