import '../game_core/board_state.dart';
import '../game_core/game_session.dart';
import '../platform_services/audio_service.dart';
import '../platform_services/haptics_service.dart';
import 'runtime_feedback.dart';

class RuntimeActionResult {
  const RuntimeActionResult({
    required this.session,
    required this.events,
  });

  final GameSession session;
  final List<RuntimeFeedbackEvent> events;
}

class RuntimeSessionDriver {
  RuntimeSessionDriver({
    required HapticsService hapticsService,
    required AudioService audioService,
  })  : _haptics = hapticsService,
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

    final placed = _diffPlacedKeys(before: current.board, after: result.session.board);
    final cleared = _diffClearedKeys(before: current.board, after: result.session.board);

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
    return after.occupied.where((key) => !before.occupied.contains(key)).toSet();
  }

  Set<int> _diffClearedKeys({
    required BoardState before,
    required BoardState after,
  }) {
    return before.occupied.where((key) => !after.occupied.contains(key)).toSet();
  }
}
