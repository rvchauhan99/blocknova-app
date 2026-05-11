import 'package:blocknova_app/game_core/game_session.dart';
import 'package:blocknova_app/game_runtime/runtime_feedback.dart';
import 'package:blocknova_app/game_runtime/runtime_session_driver.dart';
import 'package:blocknova_app/platform_services/audio_service.dart';
import 'package:blocknova_app/platform_services/haptics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Invalid placement emits rejection feedback event', () async {
    final haptics = _FakeHapticsService();
    final audio = _FakeAudioService();
    final driver = RuntimeSessionDriver(
      hapticsService: haptics,
      audioService: audio,
    );

    final session = GameSession.stage2Start();
    final result = await driver.handlePlacementTap(current: session, x: 8, y: 8);

    expect(result.session, same(session));
    expect(result.events.single.type, RuntimeEventType.placementRejected);
    expect(haptics.invalidCalls, 1);
    expect(audio.invalidCalls, 1);
  });

  test('Valid placement emits accepted feedback event', () async {
    final haptics = _FakeHapticsService();
    final audio = _FakeAudioService();
    final driver = RuntimeSessionDriver(
      hapticsService: haptics,
      audioService: audio,
    );

    final session = GameSession.stage2Start();
    final result = await driver.handlePlacementTap(current: session, x: 0, y: 0);

    expect(result.session, isNot(same(session)));
    expect(
      result.events.any(
        (event) => event.type == RuntimeEventType.placementAccepted,
      ),
      isTrue,
    );
    expect(haptics.placementCalls + haptics.clearCalls, greaterThan(0));
    expect(audio.placementCalls + audio.clearCalls, greaterThan(0));
  });
}

class _FakeHapticsService implements HapticsService {
  int placementCalls = 0;
  int clearCalls = 0;
  int invalidCalls = 0;

  @override
  Future<void> onTraySelect() async {}

  @override
  Future<void> onUiTap() async {}

  @override
  Future<void> onClear({required bool isCombo}) async {
    clearCalls += 1;
  }

  @override
  Future<void> onGameOver() async {}

  @override
  Future<void> onInvalidPlacement() async {
    invalidCalls += 1;
  }

  @override
  Future<void> onPlacement() async {
    placementCalls += 1;
  }
}

class _FakeAudioService implements AudioService {
  int placementCalls = 0;
  int clearCalls = 0;
  int invalidCalls = 0;

  @override
  Future<void> onTraySelect() async {}

  @override
  Future<void> onUiTap() async {}

  @override
  Future<void> onDragTick() async {}

  @override
  Future<void> onSplashIntro() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> onClear({required bool isCombo}) async {
    clearCalls += 1;
  }

  @override
  Future<void> onGameOver() async {}

  @override
  Future<void> onInvalidPlacement() async {
    invalidCalls += 1;
  }

  @override
  Future<void> onPlacement() async {
    placementCalls += 1;
  }
}
