import 'dart:math';

import 'package:blocknova_app/game_core/block_queue.dart';
import 'package:blocknova_app/game_core/block_shape.dart';
import 'package:blocknova_app/game_core/board_analysis.dart';
import 'package:blocknova_app/game_core/board_state.dart';
import 'package:blocknova_app/game_core/game_session.dart';
import 'package:blocknova_app/game_core/grid_point.dart';
import 'package:blocknova_app/game_core/spawn_policy.dart';
import 'package:flutter_test/flutter_test.dart';

int _singleCount(List<BlockShape> items) =>
    items.where((s) => s.id == 'single').length;

bool _hasLineClearOption(BoardState board, List<BlockShape> items) {
  for (final shape in items) {
    for (var y = 0; y < board.size; y++) {
      for (var x = 0; x < board.size; x++) {
        if (!board.canPlace(shape: shape, originX: x, originY: y)) {
          continue;
        }
        final clears = board
            .place(shape: shape, originX: x, originY: y)
            .clearCompletedLines()
            .clearedLineCount;
        if (clears > 0) {
          return true;
        }
      }
    }
  }
  return false;
}

void main() {
  test('dealQueue uses at most one single per tray (Monte Carlo)', () {
    const board = BoardState(size: 8);
    for (var seed = 0; seed < 400; seed++) {
      final rng = Random(seed);
      for (var refill = 0; refill < 8; refill++) {
        final q = BlockSpawnPolicy.dealQueue(
          board: board,
          rng: rng,
          queueRefillCount: refill,
        );
        expect(_singleCount(q.items), lessThanOrEqualTo(1));
      }
    }
  });

  test(
    'dealQueue always yields at least two usable shapes on empty board (Monte Carlo)',
    () {
      const board = BoardState(size: 8);
      for (var seed = 0; seed < 200; seed++) {
        final rng = Random(seed);
        for (var refill = 0; refill < 6; refill++) {
          final q = BlockSpawnPolicy.dealQueue(
            board: board,
            rng: rng,
            queueRefillCount: refill,
          );
          expect(q.items.length, 3);
          expect(BoardAnalysis.queueHasAnyLegalMove(board, q.items), isTrue);
          expect(
            BoardAnalysis.usableShapeCount(board, q.items),
            greaterThanOrEqualTo(2),
          );
        }
      }
    },
  );

  test('Opening refills avoid 3x3 square and cap large pieces', () {
    const board = BoardState(size: 8);
    for (var seed = 0; seed < 150; seed++) {
      final rng = Random(seed);
      for (var refill in [0, 1, 2]) {
        final q = BlockSpawnPolicy.dealQueue(
          board: board,
          rng: rng,
          queueRefillCount: refill,
        );
        expect(q.items.any((s) => s.id == 'square_3x3'), isFalse);
        expect(
          q.items.where((s) => s.tileCount >= 5).length,
          lessThanOrEqualTo(1),
        );
        expect(q.items.any((s) => s.tileCount <= 3), isTrue);
      }
    }
  });

  test('Opening trays include a useful small/medium mix', () {
    const board = BoardState(size: 8);
    for (var seed = 0; seed < 120; seed++) {
      final q = BlockSpawnPolicy.dealQueue(
        board: board,
        rng: Random(seed),
        queueRefillCount: 0,
      );

      expect(q.items.any((s) => s.tileCount <= 3), isTrue);
      expect(q.items.any((s) => s.tileCount >= 3 && s.tileCount <= 4), isTrue);
      expect(q.items.every((s) => s.tileCount <= 2), isFalse);
    }
  });

  test('Mid board trays avoid all-tiny hands and remain playable', () {
    final occupied = <int, BlockColorType>{};
    const size = 8;
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < size; x++) {
        occupied[y * size + x] = BlockColorType.cyan;
      }
    }
    final board = BoardState(size: size, cellColors: occupied);

    for (var seed = 0; seed < 100; seed++) {
      final q = BlockSpawnPolicy.dealQueue(
        board: board,
        rng: Random(seed),
        queueRefillCount: 4,
      );

      expect(BoardAnalysis.queueHasAnyLegalMove(board, q.items), isTrue);
      expect(
        BoardAnalysis.usableShapeCount(board, q.items),
        greaterThanOrEqualTo(2),
      );
      expect(q.items.every((s) => s.tileCount <= 3), isFalse);
    }
  });

  test('Danger board forces a small shape and not all-large hand', () {
    final occupied = <int, BlockColorType>{};
    const size = 8;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (x == 7 && y == 7) {
          continue;
        }
        occupied[y * size + x] = BlockColorType.purple;
      }
    }
    final board = BoardState(size: size, cellColors: occupied);
    expect(BoardAnalysis.fromBoard(board).isDanger, isTrue);
    for (var seed = 0; seed < 120; seed++) {
      final q = BlockSpawnPolicy.dealQueue(
        board: board,
        rng: Random(seed),
        queueRefillCount: 5,
      );
      expect(BoardAnalysis.queueHasAnyLegalMove(board, q.items), isTrue);
      expect(q.items.any((s) => s.tileCount <= 3), isTrue);
      expect(q.items.every((s) => s.tileCount >= 4), isFalse);
      expect(q.items.where((s) => s.tileCount >= 5).length, lessThan(2));
    }
  });

  test('dealRecoveryQueue yields playable hand on almost-full board', () {
    final occupied = <int, BlockColorType>{};
    const size = 8;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (x == 7 && y == 7) {
          continue;
        }
        occupied[y * size + x] = BlockColorType.purple;
      }
    }
    final board = BoardState(size: size, cellColors: occupied);
    for (var seed = 0; seed < 80; seed++) {
      final q = BlockSpawnPolicy.dealRecoveryQueue(
        board: board,
        rng: Random(seed),
      );
      expect(BoardAnalysis.queueHasAnyLegalMove(board, q.items), isTrue);
      expect(
        BoardAnalysis.usableShapeCount(board, q.items),
        greaterThanOrEqualTo(2),
      );
    }
  });

  test('Fragmented danger board receives compact recovery-biased shapes', () {
    final occupied = <int, BlockColorType>{};
    const size = 8;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        occupied[y * size + x] = BlockColorType.purple;
      }
    }
    for (final point in [
      const GridPoint(0, 0),
      const GridPoint(1, 0),
      const GridPoint(6, 1),
      const GridPoint(2, 4),
      const GridPoint(7, 7),
    ]) {
      occupied.remove(point.dy * size + point.dx);
    }
    final board = BoardState(size: size, cellColors: occupied);
    expect(
      BoardAnalysis.fromBoard(board).disconnectedEmptyCells,
      greaterThan(0),
    );

    for (var seed = 0; seed < 80; seed++) {
      final q = BlockSpawnPolicy.dealQueue(
        board: board,
        rng: Random(seed),
        queueRefillCount: 8,
      );

      expect(BoardAnalysis.queueHasAnyLegalMove(board, q.items), isTrue);
      expect(q.items.any((s) => s.tileCount <= 3), isTrue);
      expect(q.items.where((s) => s.tileCount >= 5).length, lessThan(2));
    }
  });

  test('Near-clear board offers at least one line-clear option', () {
    final occupied = <int, BlockColorType>{};
    const size = 8;
    for (var x = 0; x < size - 1; x++) {
      occupied[x] = BlockColorType.green;
    }
    final board = BoardState(size: size, cellColors: occupied);

    for (var seed = 0; seed < 80; seed++) {
      final q = BlockSpawnPolicy.dealQueue(
        board: board,
        rng: Random(seed),
        queueRefillCount: 4,
      );

      expect(_hasLineClearOption(board, q.items), isTrue);
    }
  });

  test('withRecoveryQueue fixes no-move game-over session', () {
    final occupied = <int, BlockColorType>{};
    const size = 8;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (x == 7 && y == 7) {
          continue;
        }
        occupied[y * size + x] = BlockColorType.purple;
      }
    }
    final lost = GameSession(
      board: BoardState(size: size, cellColors: occupied),
      queue: const BlockQueue([
        BlockShape(
          id: 'domino_h',
          cells: [GridPoint(0, 0), GridPoint(1, 0)],
          colorType: BlockColorType.purple,
        ),
      ]),
      selectedQueueIndex: 0,
      isGameOver: true,
      queueRefillCount: 2,
    );
    expect(lost.hasAnyValidMove(), isFalse);
    final resumed = lost.withRecoveryQueue(Random(42));
    expect(resumed.isGameOver, isFalse);
    expect(resumed.hasAnyValidMove(), isTrue);
  });

  test('dealQueue solvable on random partial boards (Monte Carlo)', () {
    for (var seed = 0; seed < 100; seed++) {
      final rng = Random(seed);
      final cells = <int, BlockColorType>{};
      for (var k = 0; k < 40; k++) {
        cells[rng.nextInt(64)] = BlockColorType.cyan;
      }
      final board = BoardState(size: 8, cellColors: cells);
      final q = BlockSpawnPolicy.dealQueue(
        board: board,
        rng: rng,
        queueRefillCount: 4,
      );
      expect(BoardAnalysis.queueHasAnyLegalMove(board, q.items), isTrue);
      expect(
        BoardAnalysis.usableShapeCount(board, q.items),
        greaterThanOrEqualTo(2),
      );
      expect(_singleCount(q.items), lessThanOrEqualTo(1));
    }
  });

  test('dealRecoveryQueue uses at most two singles on danger board', () {
    final occupied = <int, BlockColorType>{};
    const size = 8;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (x == 7 && y == 7) {
          continue;
        }
        occupied[y * size + x] = BlockColorType.purple;
      }
    }
    final board = BoardState(size: size, cellColors: occupied);
    expect(BoardAnalysis.fromBoard(board).isDanger, isTrue);
    for (var seed = 0; seed < 120; seed++) {
      final q = BlockSpawnPolicy.dealRecoveryQueue(
        board: board,
        rng: Random(seed),
      );
      expect(_singleCount(q.items), lessThanOrEqualTo(2));
      expect(BoardAnalysis.queueHasAnyLegalMove(board, q.items), isTrue);
    }
  });

  test(
    'dealRecoveryQueue uses at most one single when board is not danger',
    () {
      final cells = <int, BlockColorType>{};
      for (var i = 0; i < 10; i++) {
        cells[(i * 6) % 64] = BlockColorType.cyan;
      }
      final board = BoardState(size: 8, cellColors: cells);
      expect(BoardAnalysis.fromBoard(board).isDanger, isFalse);
      for (var seed = 0; seed < 80; seed++) {
        final q = BlockSpawnPolicy.dealRecoveryQueue(
          board: board,
          rng: Random(seed),
        );
        expect(_singleCount(q.items), lessThanOrEqualTo(1));
        expect(BoardAnalysis.queueHasAnyLegalMove(board, q.items), isTrue);
      }
    },
  );

  test(
    'queueRefillCount increments after three single placements empty tray',
    () {
      const single = BlockShape(
        id: 'single',
        cells: [GridPoint(0, 0)],
        colorType: BlockColorType.purple,
      );
      var session = GameSession(
        board: const BoardState(size: 8),
        queue: const BlockQueue([single, single, single]),
        selectedQueueIndex: 0,
        queueRefillCount: 0,
      );
      expect(session.queueRefillCount, 0);
      session = session.placeSelectedAt(0, 0).session;
      expect(session.queueRefillCount, 0);
      session = session.placeSelectedAt(1, 0).session;
      expect(session.queueRefillCount, 0);
      session = session.placeSelectedAt(2, 0).session;
      expect(session.queueRefillCount, 1);
      expect(session.queue.items.length, 3);
      expect(session.hasAnyValidMove(), isTrue);
    },
  );
}
