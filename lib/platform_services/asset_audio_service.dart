import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_service.dart';

/// Plays bundled original SFX from [assets/sfx/]. Safe no-op on failure (missing asset, web quirks).
class AssetAudioService implements AudioService {
  AssetAudioService({this.enabled = true});

  final bool enabled;

  final List<AudioPlayer> _pool = List<AudioPlayer>.generate(
    5,
    (_) => AudioPlayer(),
    growable: false,
  );
  int _next = 0;

  AudioPlayer _take() {
    final p = _pool[_next % _pool.length];
    _next++;
    return p;
  }

  Future<void> _playAsset(String relativePath, {double volume = 1}) async {
    if (!enabled || kIsWeb) {
      return;
    }
    final player = _take();
    try {
      await player.stop();
      await player.setVolume(volume.clamp(0, 1));
      await player.play(AssetSource(relativePath));
    } catch (e, st) {
      debugPrint('AssetAudioService play failed: $e\n$st');
    }
  }

  @override
  Future<void> onTraySelect() => _playAsset('sfx/tray_select.wav', volume: 0.95);

  @override
  Future<void> onUiTap() => _playAsset('sfx/ui_tap.wav', volume: 0.85);

  @override
  Future<void> onDragTick() => _playAsset('sfx/drag_tick.wav', volume: 0.7);

  @override
  Future<void> onPlacement() => _playAsset('sfx/placement.wav');

  @override
  Future<void> onClear({required bool isCombo}) {
    if (isCombo) {
      return _playAsset('sfx/combo_rise.wav');
    }
    return _playAsset('sfx/line_clear.wav');
  }

  @override
  Future<void> onInvalidPlacement() => _playAsset('sfx/invalid.wav');

  @override
  Future<void> onGameOver() => _playAsset('sfx/game_over.wav', volume: 0.9);

  @override
  Future<void> onSplashIntro() => _playAsset('sfx/splash_intro.wav', volume: 0.85);

  @override
  Future<void> dispose() async {
    for (final p in _pool) {
      await p.dispose();
    }
  }
}
