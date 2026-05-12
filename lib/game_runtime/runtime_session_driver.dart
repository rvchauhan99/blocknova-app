import '../game_core/board_state.dart';
import '../game_core/game_session.dart';
import '../platform_services/audio_service.dart';
import '../platform_services/haptics_service.dart';
import 'runtime_feedback.dart';

class RuntimeActionResult {
  const RuntimeActionResult({required this.session, required this.events});

  final GameSession session;
  final List<RuntimeFeedbackEvent> events;
}

class RuntimeSessionDriver {
  RuntimeSessionDriver({
    required HapticsService hapticsService,
    required AudioService audioService,
  }) : _haptics = hapticsService,
       _audio = audioService;

  final HapticsService _haptics;
  final AudioService _audio;

  Future<RuntimeActionResult> handlePlacementTap({
    required GameSession current,
    required int x,
    required int y,
  }) async {
    final result = current.placeSelectedAt(x, y);

    if (!result.accepted) {
      await _haptics.onInvalidPlacement();
      await _audio.onInvalidPlacement();
      return RuntimeActionResult(
        session: current,
        events: [
          RuntimeFeedbackEvent(
            type: RuntimeEventType.placementRejected,
            message: result.reason ?? 'Invalid placement',
            invalidTapKey: current.board.keyFor(x, y),
          ),
        ],
      );
    }

    final shape = current.selectedShape!;
    final placedBoard = current.board.place(
      shape: shape,
      originX: x,
      originY: y,
    );
    final clearResult = placedBoard.clearCompletedLines();
    final cleared = _clearedLineKeys(placedBoard, clearResult);
    final placed = _diffPlacedKeys(
      before: current.board,
      after: placedBoard,
    ).difference(cleared);

    final events = <RuntimeFeedbackEvent>[
      RuntimeFeedbackEvent(
        type: RuntimeEventType.placementAccepted,
        message: 'Placed +${result.session.lastMoveScore}',
        placedKeys: placed,
      ),
    ];

    if (result.session.lastMoveClears > 0) {
      final isCombo = result.session.comboCount > 1;
      await _haptics.onClear(isCombo: isCombo);
      await _audio.onClear(isCombo: isCombo);

      events.add(
        RuntimeFeedbackEvent(
          type: RuntimeEventType.lineClear,
          message: 'Cleared ${result.session.lastMoveClears} line(s)',
          clearedLines: result.session.lastMoveClears,
          comboCount: result.session.comboCount,
          clearedKeys: cleared,
        ),
      );
      if (isCombo) {
        events.add(
          RuntimeFeedbackEvent(
            type: RuntimeEventType.combo,
            message: 'Combo x${result.session.comboCount}',
            comboCount: result.session.comboCount,
          ),
        );
      }
    } else {
      await _haptics.onPlacement();
      await _audio.onPlacement();
    }

    if (result.session.isGameOver) {
      await _haptics.onGameOver();
      await _audio.onGameOver();
      events.add(
        const RuntimeFeedbackEvent(
          type: RuntimeEventType.gameOver,
          message: 'No valid moves',
        ),
      );
    }

    return RuntimeActionResult(session: result.session, events: events);
  }

  Set<int> _diffPlacedKeys({
    required BoardState before,
    required BoardState after,
  }) {
    return after.occupied
        .where((key) => !before.occupied.contains(key))
        .toSet();
  }

  Set<int> _clearedLineKeys(BoardState placedBoard, ClearResult clearResult) {
    final keys = <int>{};
    for (final y in clearResult.clearedRows) {
      for (var x = 0; x < placedBoard.size; x++) {
        keys.add(placedBoard.keyFor(x, y));
      }
    }
    for (final x in clearResult.clearedCols) {
      for (var y = 0; y < placedBoard.size; y++) {
        keys.add(placedBoard.keyFor(x, y));
      }
    }
    return keys;
  }
}
