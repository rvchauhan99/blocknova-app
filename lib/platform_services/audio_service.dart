import 'package:flutter/foundation.dart';

abstract class AudioService {
  Future<void> onTraySelect();
  Future<void> onUiTap();
  Future<void> onDragTick();
  Future<void> onPlacement();
  Future<void> onClear({required bool isCombo});
  Future<void> onInvalidPlacement();
  Future<void> onGameOver();
  Future<void> onSplashIntro();

  /// Release native players when applicable.
  Future<void> dispose();
}

class StubAudioService implements AudioService {
  @override
  Future<void> onTraySelect() async {
    debugPrint('[audio] tray_select');
  }

  @override
  Future<void> onUiTap() async {
    debugPrint('[audio] ui_tap');
  }

  @override
  Future<void> onDragTick() async {
    debugPrint('[audio] drag_tick');
  }

  @override
  Future<void> onPlacement() async {
    debugPrint('[audio] placement');
  }

  @override
  Future<void> onClear({required bool isCombo}) async {
    debugPrint('[audio] clear combo=$isCombo');
  }

  @override
  Future<void> onInvalidPlacement() async {
    debugPrint('[audio] invalid placement');
  }

  @override
  Future<void> onGameOver() async {
    debugPrint('[audio] game over');
  }

  @override
  Future<void> onSplashIntro() async {
    debugPrint('[audio] splash_intro');
  }

  @override
  Future<void> dispose() async {}
}
