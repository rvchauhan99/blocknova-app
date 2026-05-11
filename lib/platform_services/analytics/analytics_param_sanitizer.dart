/// Converts arbitrary analytics parameters to Firebase Analytics–safe
/// [String] or [num] values, with stable key truncation.
Map<String, Object> sanitizeAnalyticsParameters(
  Map<String, Object?> parameters, {
  int maxParamNameLength = 40,
  int maxStringValueLength = 100,
}) {
  final out = <String, Object>{};
  for (final entry in parameters.entries) {
    final rawKey = entry.key;
    if (rawKey.isEmpty) {
      continue;
    }
    final key = rawKey.length > maxParamNameLength
        ? rawKey.substring(0, maxParamNameLength)
        : rawKey;
    final value = entry.value;
    if (value == null) {
      continue;
    }
    if (value is String) {
      out[key] = value.length > maxStringValueLength
          ? value.substring(0, maxStringValueLength)
          : value;
    } else if (value is int) {
      out[key] = value;
    } else if (value is double) {
      out[key] = value;
    } else if (value is num) {
      out[key] = value is int ? value.toInt() : value.toDouble();
    } else if (value is bool) {
      out[key] = value ? 1 : 0;
    } else {
      final s = value.toString();
      out[key] = s.length > maxStringValueLength
          ? s.substring(0, maxStringValueLength)
          : s;
    }
  }
  return out;
}

/// Firebase Analytics [logEvent] rejects reserved names; map our schema names.
String firebaseTransportEventName(String logicalName) {
  switch (logicalName) {
    case 'session_start':
      return 'bn_session_start';
    default:
      return logicalName;
  }
}
