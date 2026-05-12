import 'package:blocknova_app/game_core/block_shape.dart';
import 'package:blocknova_app/game_core/board_analysis.dart';
import 'package:blocknova_app/game_core/board_state.dart';
import 'package:blocknova_app/game_core/grid_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Empty board analysis is not danger and has many placements', () {
    const board = BoardState(size: 8);
    final a = BoardAnalysis.fromBoard(board);
    expect(a.occupancy, 0);
    expect(a.emptyCells, 64);
    expect(a.isDanger, isFalse);
    expect(a.shapesWithAnyPlacement, kShapePool.length);
    expect(a.totalLegalPlacements, greaterThan(500));
    expect(a.largestEmptyRegion, 64);
    expect(a.disconnectedEmptyCells, 0);
  });

  test('Almost-full board is danger and single still fits one hole', () {
    final occupied = <int, BlockColorType>{};
    const size = 8;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (x == 3 && y == 3) {
          continue;
        }
        occupied[y * size + x] = BlockColorType.purple;
      }
    }
    final board = BoardState(size: size, cellColors: occupied);
    final a = BoardAnalysis.fromBoard(board);
    expect(a.occupancy, 63);
    expect(a.isDanger, isTrue);
    const single = BlockShape(
      id: 'single',
      cells: [GridPoint(0, 0)],
      colorType: BlockColorType.purple,
    );
    expect(BoardAnalysis.legalPlacementCount(board, single), 1);
  });

  test('Fragmented board reports empty cells outside largest region', () {
    final occupied = <int, BlockColorType>{};
    const size = 8;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        occupied[y * size + x] = BlockColorType.blue;
      }
    }

    for (final point in [
      const GridPoint(0, 0),
      const GridPoint(1, 0),
      const GridPoint(0, 1),
      const GridPoint(7, 7),
      const GridPoint(5, 5),
    ]) {
      occupied.remove(point.dy * size + point.dx);
    }

    final a = BoardAnalysis.fromBoard(
      BoardState(size: size, cellColors: occupied),
    );

    expect(a.emptyCells, 5);
    expect(a.largestEmptyRegion, 3);
    expect(a.disconnectedEmptyCells, 2);
  });

  test('usableShapeCount counts queue slots with at least one placement', () {
    const board = BoardState(size: 8);
    const s = BlockShape(
      id: 'single',
      cells: [GridPoint(0, 0)],
      colorType: BlockColorType.purple,
    );
    expect(BoardAnalysis.usableShapeCount(board, [s, s, s]), 3);
  });
}
