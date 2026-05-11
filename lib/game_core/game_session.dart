import 'dart:math' as dart_math;

import 'block_queue.dart';
import 'block_shape.dart';
import 'board_state.dart';
import 'scoring.dart';
import 'spawn_policy.dart';

class PlacementResult {
  const PlacementResult({
    required this.accepted,
    required this.session,
    this.reason,
  });

  final bool accepted;
  final GameSession session;
  final String? reason;
}

class GameSession {
  const GameSession({
    required this.board,
    required this.queue,
    this.selectedQueueIndex = 0,
    this.isGameOver = false,
    this.score = 0,
    this.comboCount = 0,
    this.streakCount = 0,
    this.lastMoveClears = 0,
    this.lastMoveScore = 0,
    this.queueRefillCount = 0,
  });

  factory GameSession.stage2Start() {
    return GameSession(
      board: const BoardState(size: 8),
      queue: BlockQueue.stage2Starter(),
      selectedQueueIndex: 0,
      isGameOver: false,
      score: 0,
      comboCount: 0,
      streakCount: 0,
      lastMoveClears: 0,
      lastMoveScore: 0,
      queueRefillCount: 0,
    );
  }

  final BoardState board;
  final BlockQueue queue;
  final int selectedQueueIndex;
  final bool isGameOver;
  final int score;
  final int comboCount;
  final int streakCount;
  final int lastMoveClears;
  final int lastMoveScore;

  /// Increments each time a new full tray of 3 blocks is dealt after the tray emptied.
  final int queueRefillCount;

  BlockShape? get selectedShape => queue.at(selectedQueueIndex);

  GameSession selectQueueIndex(int index) {
    return GameSession(
      board: board,
      queue: queue,
      selectedQueueIndex: index,
      isGameOver: isGameOver,
      score: score,
      comboCount: comboCount,
      streakCount: streakCount,
      lastMoveClears: lastMoveClears,
      lastMoveScore: lastMoveScore,
      queueRefillCount: queueRefillCount,
    );
  }

  /// After rewarded continue: playable queue on the same board, same refill bookkeeping.
  GameSession withRecoveryQueue(dart_math.Random rng) {
    return GameSession(
      board: board,
      queue: BlockSpawnPolicy.dealRecoveryQueue(board: board, rng: rng),
      selectedQueueIndex: 0,
      isGameOver: false,
      score: score,
      comboCount: comboCount,
      streakCount: streakCount,
      lastMoveClears: lastMoveClears,
      lastMoveScore: lastMoveScore,
      queueRefillCount: queueRefillCount,
    );
  }

  bool canPlaceSelectedAt(int x, int y) {
    final shape = selectedShape;
    if (shape == null || isGameOver) {
      return false;
    }
    return board.canPlace(shape: shape, originX: x, originY: y);
  }

  bool hasAnyValidMoveForShape(BlockShape shape) {
    for (var y = 0; y < board.size; y++) {
      for (var x = 0; x < board.size; x++) {
        if (board.canPlace(shape: shape, originX: x, originY: y)) {
          return true;
        }
      }
    }
    return false;
  }

  bool hasAnyValidMove() {
    for (final shape in queue.items) {
      if (hasAnyValidMoveForShape(shape)) {
        return true;
      }
    }
    return false;
  }

  PlacementResult placeSelectedAt(int x, int y) {
    final shape = selectedShape;
    if (shape == null) {
      return PlacementResult(
        accepted: false,
        session: this,
        reason: 'no_shape_selected',
      );
    }
    if (isGameOver) {
      return PlacementResult(
        accepted: false,
        session: this,
        reason: 'game_over',
      );
    }
    if (!board.canPlace(shape: shape, originX: x, originY: y)) {
      return PlacementResult(
        accepted: false,
        session: this,
        reason: 'invalid_placement',
      );
    }

    final placedBoard = board.place(shape: shape, originX: x, originY: y);
    final clearResult = placedBoard.clearCompletedLines();
    final clearedLines = clearResult.clearedLineCount;
    final nextCombo = clearedLines > 0 ? comboCount + 1 : 0;
    final nextStreak = clearedLines > 0 ? streakCount + 1 : 0;
    final scoreDelta = computeMoveScore(
      placedTileCount: shape.tileCount,
      clearedLines: clearedLines,
      comboCount: nextCombo,
      streakCount: nextStreak,
    ).total;

    final nextBoard = clearResult.board;
    var nextQueue = queue.removeAt(selectedQueueIndex);
    var nextRefillCount = queueRefillCount;
    if (nextQueue.isEmpty) {
      nextRefillCount = queueRefillCount + 1;
      nextQueue = BlockSpawnPolicy.dealQueue(
        board: nextBoard,
        rng: dart_math.Random(),
        queueRefillCount: nextRefillCount,
      );
    }
    const nextSelected = 0;

    // Evaluate if there are any valid moves with the next queue
    final provisionalSession = GameSession(
      board: nextBoard,
      queue: nextQueue,
      selectedQueueIndex: nextSelected,
      score: score + scoreDelta,
      comboCount: nextCombo,
      streakCount: nextStreak,
      lastMoveClears: clearedLines,
      lastMoveScore: scoreDelta,
      queueRefillCount: nextRefillCount,
    );

    final next = GameSession(
      board: nextBoard,
      queue: nextQueue,
      selectedQueueIndex: nextSelected,
      score: score + scoreDelta,
      comboCount: nextCombo,
      streakCount: nextStreak,
      lastMoveClears: clearedLines,
      lastMoveScore: scoreDelta,
      isGameOver: !provisionalSession.hasAnyValidMove(),
      queueRefillCount: nextRefillCount,
    );
    return PlacementResult(accepted: true, session: next);
  }
}
