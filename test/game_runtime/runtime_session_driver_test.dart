import 'package:blocknova_app/game_core/block_queue.dart';
import 'package:blocknova_app/game_core/block_shape.dart';
import 'package:blocknova_app/game_core/board_state.dart';
import 'package:blocknova_app/game_core/game_session.dart';
import 'package:blocknova_app/game_core/grid_point.dart';
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
    final result = await driver.handlePlacementTap(
      current: session,
      x: 8,
      y: 8,
    );

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
    final result = await driver.handlePlacementTap(
      current: session,
      x: 0,
      y: 0,
    );

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

  test('Row clear feedback includes newly placed cells', () async {
    final driver = RuntimeSessionDriver(
      hapticsService: _FakeHapticsService(),
      audioService: _FakeAudioService(),
    );
    final board = _boardWithOccupiedCells({
      for (var x = 0; x < 6; x++) GridPoint(x, 0),
    });
    final session = GameSession(
      board: board,
      queue: const BlockQueue([
        BlockShape(
          colorType: BlockColorType.blue,
          id: 'test_domino_h',
          cells: [GridPoint(0, 0), GridPoint(1, 0)],
        ),
      ]),
    );

    final result = await driver.handlePlacementTap(
      current: session,
      x: 6,
      y: 0,
    );
    final lineClear = result.events.firstWhere(
      (event) => event.type == RuntimeEventType.lineClear,
    );

    expect(lineClear.clearedKeys, {for (var x = 0; x < 8; x++) x});
    expect(lineClear.clearedKeys, containsAll(<int>[6, 7]));
  });

  test('Column clear feedback includes full cleared column', () async {
    final driver = RuntimeSessionDriver(
      hapticsService: _FakeHapticsService(),
      audioService: _FakeAudioService(),
    );
    final board = _boardWithOccupiedCells({
      for (var y = 0; y < 6; y++) GridPoint(0, y),
    });
    final session = GameSession(
      board: board,
      queue: const BlockQueue([
        BlockShape(
          colorType: BlockColorType.blue,
          id: 'test_domino_v',
          cells: [GridPoint(0, 0), GridPoint(0, 1)],
        ),
      ]),
    );

    final result = await driver.handlePlacementTap(
      current: session,
      x: 0,
      y: 6,
    );
    final lineClear = result.events.firstWhere(
      (event) => event.type == RuntimeEventType.lineClear,
    );

    expect(lineClear.clearedKeys, {for (var y = 0; y < 8; y++) y * 8});
    expect(lineClear.clearedKeys, containsAll(<int>[48, 56]));
  });

  test(
    'Simultaneous row and column clear feedback includes line union',
    () async {
      final driver = RuntimeSessionDriver(
        hapticsService: _FakeHapticsService(),
        audioService: _FakeAudioService(),
      );
      final board = _boardWithOccupiedCells({
        for (var x = 0; x < 7; x++) GridPoint(x, 0),
        for (var y = 1; y < 8; y++) GridPoint(7, y),
      });
      final session = GameSession(
        board: board,
        queue: const BlockQueue([
          BlockShape(
            colorType: BlockColorType.purple,
            id: 'single',
            cells: [GridPoint(0, 0)],
          ),
        ]),
      );

      final result = await driver.handlePlacementTap(
        current: session,
        x: 7,
        y: 0,
      );
      final lineClear = result.events.firstWhere(
        (event) => event.type == RuntimeEventType.lineClear,
      );

      final expected = <int>{
        for (var x = 0; x < 8; x++) x,
        for (var y = 0; y < 8; y++) y * 8 + 7,
      };
      expect(lineClear.clearedKeys, expected);
      expect(lineClear.clearedKeys.length, 15);
    },
  );
}

BoardState _boardWithOccupiedCells(Set<GridPoint> points) {
  return BoardState(
    size: 8,
    cellColors: {
      for (final point in points)
        point.dy * 8 + point.dx: BlockColorType.purple,
    },
  );
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
