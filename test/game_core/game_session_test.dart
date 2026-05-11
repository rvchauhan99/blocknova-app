import 'package:blocknova_app/game_core/block_queue.dart';
import 'package:blocknova_app/game_core/block_shape.dart';
import 'package:blocknova_app/game_core/board_state.dart';
import 'package:blocknova_app/game_core/game_session.dart';
import 'package:blocknova_app/game_core/grid_point.dart';
import 'package:blocknova_app/game_core/scoring.dart';
import 'package:blocknova_app/game_core/scoring_config.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Valid placement is accepted', () {
    final session = GameSession.stage2Start();
    final result = session.placeSelectedAt(0, 0);
    expect(result.accepted, isTrue);
    expect(result.session.score, greaterThan(0));
  });

  test('Out-of-bounds placement is rejected', () {
    final session = GameSession.stage2Start();
    final result = session.placeSelectedAt(8, 8);
    expect(result.accepted, isFalse);
    expect(result.reason, 'invalid_placement');
  });

  test('Collision placement is rejected', () {
    final session = GameSession.stage2Start();
    final first = session.placeSelectedAt(0, 0);
    expect(first.accepted, isTrue);

    final second = first.session.placeSelectedAt(0, 0);
    expect(second.accepted, isFalse);
    expect(second.reason, 'invalid_placement');
  });

  test('Queue shrinks after successful placement', () {
    final session = GameSession.stage2Start();
    final before = session.queue.items.length;
    final result = session.placeSelectedAt(0, 0);
    expect(result.accepted, isTrue);
    expect(result.session.queue.items.length, before - 1);
  });

  test('Single line clear applies clear bonus and combo/streak increments', () {
    // Fill top row with singles except x=7 and keep a single selected.
    var session = GameSession(
      board: _emptyBoardSession().board,
      queue: const BlockQueue([
        BlockShape(colorType: BlockColorType.purple, id: 'single', cells: [GridPoint(0, 0)]),
      ]),
      selectedQueueIndex: 0,
      isGameOver: false,
    );

    for (var x = 0; x < 7; x++) {
      final place = session.placeSelectedAt(x, 0);
      expect(place.accepted, isTrue);
      session = GameSession(
        board: place.session.board,
        queue: const BlockQueue([
          BlockShape(colorType: BlockColorType.purple, id: 'single', cells: [GridPoint(0, 0)]),
        ]),
        selectedQueueIndex: 0,
        isGameOver: false,
        score: place.session.score,
        comboCount: place.session.comboCount,
        streakCount: place.session.streakCount,
        lastMoveClears: place.session.lastMoveClears,
        lastMoveScore: place.session.lastMoveScore,
      );
    }

    final clearMove = session.placeSelectedAt(7, 0);
    expect(clearMove.accepted, isTrue);
    expect(clearMove.session.lastMoveClears, 1);
    expect(clearMove.session.comboCount, 1);
    expect(clearMove.session.streakCount, 1);
    expect(
      clearMove.session.lastMoveScore,
      greaterThanOrEqualTo(
        ScoringConfig.placementPointPerTile + ScoringConfig.lineClearBonus,
      ),
    );
  });

  test('Combo increments on consecutive clears and resets on non-clear move', () {
    final base = _boardWithTwoAlmostCompleteRows();

    final firstClear = base.placeSelectedAt(7, 0);
    expect(firstClear.accepted, isTrue);
    expect(firstClear.session.comboCount, 1);

    // Row 1 is already almost complete from setup, so next clear is consecutive.
    final continueSession = GameSession(
      board: firstClear.session.board,
      queue: const BlockQueue([
        BlockShape(colorType: BlockColorType.purple, id: 'single', cells: [GridPoint(0, 0)]),
      ]),
      selectedQueueIndex: 0,
      isGameOver: false,
      score: firstClear.session.score,
      comboCount: firstClear.session.comboCount,
      streakCount: firstClear.session.streakCount,
      lastMoveClears: firstClear.session.lastMoveClears,
      lastMoveScore: firstClear.session.lastMoveScore,
    );
    final secondClear = continueSession.placeSelectedAt(7, 1);
    expect(secondClear.accepted, isTrue);
    expect(secondClear.session.comboCount, 2);

    // Non-clear move resets combo.
    final nonClear = GameSession(
      board: secondClear.session.board,
      queue: const BlockQueue([
        BlockShape(colorType: BlockColorType.purple, id: 'single', cells: [GridPoint(0, 0)]),
      ]),
      selectedQueueIndex: 0,
      isGameOver: false,
      score: secondClear.session.score,
      comboCount: secondClear.session.comboCount,
      streakCount: secondClear.session.streakCount,
      lastMoveClears: secondClear.session.lastMoveClears,
      lastMoveScore: secondClear.session.lastMoveScore,
    ).placeSelectedAt(7, 7);
    expect(nonClear.accepted, isTrue);
    expect(nonClear.session.lastMoveClears, 0);
    expect(nonClear.session.comboCount, 0);
    expect(nonClear.session.streakCount, 0);
  });

  test('Streak bonus cap is deterministic in scoring function', () {
    final atCap = computeMoveScore(
      placedTileCount: 1,
      clearedLines: 1,
      comboCount: 1,
      streakCount: ScoringConfig.streakCap + 1,
    );
    final beyondCap = computeMoveScore(
      placedTileCount: 1,
      clearedLines: 1,
      comboCount: 1,
      streakCount: ScoringConfig.streakCap + 3,
    );
    expect(beyondCap.streakBonus, atCap.streakBonus);
  });

  test('Game over when no valid move exists for remaining queue', () {
    final occupied = <int>{};
    const size = 8;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (x == 7 && y == 7) {
          continue;
        }
        occupied.add(y * size + x);
      }
    }
    final blockedSession = GameSession(
      board: BoardState(size: size, cellColors: { for (var k in occupied) k: BlockColorType.purple }),
      queue: const BlockQueue([
        BlockShape(colorType: BlockColorType.purple, 
          id: 'domino_h',
          cells: [GridPoint(0, 0), GridPoint(1, 0)],
        ),
      ]),
      selectedQueueIndex: 0,
      isGameOver: false,
    );

    final canMove = blockedSession.hasAnyValidMove();
    expect(canMove, isFalse);

    final failed = blockedSession.placeSelectedAt(7, 7);
    expect(failed.accepted, isFalse);
  });
}

GameSession _emptyBoardSession() => GameSession.stage2Start();

GameSession _boardWithAlmostCompleteRow(int rowY) {
  var session = GameSession(
    board: _emptyBoardSession().board,
    queue: const BlockQueue([
      BlockShape(colorType: BlockColorType.purple, id: 'single', cells: [GridPoint(0, 0)]),
    ]),
    selectedQueueIndex: 0,
    isGameOver: false,
  );
  for (var x = 0; x < 7; x++) {
    final result = session.placeSelectedAt(x, rowY);
    if (!result.accepted) {
      continue;
    }
    session = GameSession(
      board: result.session.board,
      queue: const BlockQueue([
        BlockShape(colorType: BlockColorType.purple, id: 'single', cells: [GridPoint(0, 0)]),
      ]),
      selectedQueueIndex: 0,
      isGameOver: false,
      score: result.session.score,
      comboCount: result.session.comboCount,
      streakCount: result.session.streakCount,
      lastMoveClears: result.session.lastMoveClears,
      lastMoveScore: result.session.lastMoveScore,
    );
  }
  return session;
}

GameSession _boardWithTwoAlmostCompleteRows() {
  var session = _boardWithAlmostCompleteRow(0);
  for (var x = 0; x < 7; x++) {
    final res = session.placeSelectedAt(x, 1);
    if (!res.accepted) {
      continue;
    }
    session = GameSession(
      board: res.session.board,
      queue: const BlockQueue([
        BlockShape(colorType: BlockColorType.purple, id: 'single', cells: [GridPoint(0, 0)]),
      ]),
      selectedQueueIndex: 0,
      isGameOver: false,
      score: res.session.score,
      comboCount: res.session.comboCount,
      streakCount: res.session.streakCount,
      lastMoveClears: res.session.lastMoveClears,
      lastMoveScore: res.session.lastMoveScore,
    );
  }
  return session;
}
