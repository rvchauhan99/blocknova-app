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

  test('dealRecoveryQueue uses at most one single when board is not danger', () {
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
  });

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
