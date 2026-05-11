import 'package:flutter/services.dart';

abstract class HapticsService {
  Future<void> onTraySelect();
  Future<void> onUiTap();
  Future<void> onPlacement();
  Future<void> onClear({required bool isCombo});
  Future<void> onInvalidPlacement();
  Future<void> onGameOver();
}

class SystemHapticsService implements HapticsService {
  @override
  Future<void> onTraySelect() => HapticFeedback.selectionClick();

  @override
  Future<void> onUiTap() => HapticFeedback.lightImpact();

  @override
  Future<void> onPlacement() => HapticFeedback.mediumImpact();

  @override
  Future<void> onClear({required bool isCombo}) {
    if (isCombo) {
      return HapticFeedback.heavyImpact();
    }
    return HapticFeedback.mediumImpact();
  }

  @override
  Future<void> onInvalidPlacement() => HapticFeedback.lightImpact();

  @override
  Future<void> onGameOver() => HapticFeedback.vibrate();
}
