import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Ensures a signed-in user for callable Cloud Functions (`submitRun`, etc.).
///
/// Returns true when [FirebaseAuth.instance.currentUser] is non-null after the call.
Future<bool> ensureAnonymousAuth() async {
  if (Firebase.apps.isEmpty) {
    return false;
  }
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    return FirebaseAuth.instance.currentUser != null;
  } catch (e) {
    debugPrint('Anonymous auth failed: $e');
    return false;
  }
}
