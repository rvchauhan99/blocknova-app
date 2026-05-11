enum RuntimeEventType {
  placementAccepted,
  placementRejected,
  lineClear,
  combo,
  gameOver,
}

class RuntimeFeedbackEvent {
  const RuntimeFeedbackEvent({
    required this.type,
    required this.message,
    this.placedKeys = const <int>{},
    this.clearedKeys = const <int>{},
    this.invalidTapKey,
    this.comboCount = 0,
    this.clearedLines = 0,
  });

  final RuntimeEventType type;
  final String message;
  final Set<int> placedKeys;
  final Set<int> clearedKeys;
  final int? invalidTapKey;
  final int comboCount;
  final int clearedLines;
}
