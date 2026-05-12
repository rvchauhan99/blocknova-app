import 'block_shape.dart';
import 'board_state.dart';

/// Read-only snapshot of board pressure for spawn / recovery policy.
class BoardAnalysis {
  const BoardAnalysis({
    required this.occupancy,
    required this.emptyCells,
    required this.nearFullRowCount,
    required this.nearFullColCount,
    required this.fragmentedHoleScore,
    required this.largestEmptyRegion,
    required this.totalLegalPlacements,
    required this.shapesWithAnyPlacement,
    required this.isDanger,
  });

  /// Occupied cell count.
  final int occupancy;

  /// Empty cell count (size*size - occupancy).
  final int emptyCells;

  /// Rows with at least [nearFullThreshold] occupied cells.
  final int nearFullRowCount;

  /// Columns with at least [nearFullThreshold] occupied cells.
  final int nearFullColCount;

  /// Higher when empty cells are poorly connected (rough fragmentation proxy).
  final int fragmentedHoleScore;

  /// Largest 4-way connected group of empty cells.
  final int largestEmptyRegion;

  /// Empty cells outside the largest connected group.
  int get disconnectedEmptyCells => emptyCells - largestEmptyRegion;

  /// Sum over [kShapePool] of legal placement counts (can be large; used relatively).
  final int totalLegalPlacements;

  /// How many distinct pool shapes have at least one legal placement.
  final int shapesWithAnyPlacement;

  /// Board is considered dangerous: very full and/or very few options.
  final bool isDanger;

  static const int nearFullThreshold = 6;
  static const int dangerOccupancy = 44;
  static const int dangerTotalPlacements = 120;

  static BoardAnalysis fromBoard(BoardState board) {
    final size = board.size;
    final cap = size * size;
    final occ = board.occupied.length;
    final empty = cap - occ;

    var nearRows = 0;
    for (var y = 0; y < size; y++) {
      var rowOcc = 0;
      for (var x = 0; x < size; x++) {
        if (board.isOccupied(x, y)) {
          rowOcc++;
        }
      }
      if (rowOcc >= nearFullThreshold) {
        nearRows++;
      }
    }

    var nearCols = 0;
    for (var x = 0; x < size; x++) {
      var colOcc = 0;
      for (var y = 0; y < size; y++) {
        if (board.isOccupied(x, y)) {
          colOcc++;
        }
      }
      if (colOcc >= nearFullThreshold) {
        nearCols++;
      }
    }

    var frag = 0;
    final visited = <int>{};
    var largestRegion = 0;
    const neighDx = <int>[1, -1, 0, 0];
    const neighDy = <int>[0, 0, 1, -1];
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (board.isOccupied(x, y)) {
          continue;
        }
        var emptyNeigh = 0;
        for (var i = 0; i < 4; i++) {
          final nx = x + neighDx[i];
          final ny = y + neighDy[i];
          if (nx < 0 || ny < 0 || nx >= size || ny >= size) {
            continue;
          }
          if (!board.isOccupied(nx, ny)) {
            emptyNeigh++;
          }
        }
        if (emptyNeigh <= 1) {
          frag++;
        }

        final start = board.keyFor(x, y);
        if (visited.contains(start)) {
          continue;
        }
        var region = 0;
        final pending = <int>[start];
        visited.add(start);
        while (pending.isNotEmpty) {
          final key = pending.removeLast();
          region++;
          final cx = key % size;
          final cy = key ~/ size;
          for (var i = 0; i < 4; i++) {
            final nx = cx + neighDx[i];
            final ny = cy + neighDy[i];
            if (nx < 0 || ny < 0 || nx >= size || ny >= size) {
              continue;
            }
            if (board.isOccupied(nx, ny)) {
              continue;
            }
            final next = board.keyFor(nx, ny);
            if (visited.add(next)) {
              pending.add(next);
            }
          }
        }
        if (region > largestRegion) {
          largestRegion = region;
        }
      }
    }

    var totalPlacements = 0;
    var shapesOk = 0;
    for (final shape in kShapePool) {
      final n = legalPlacementCount(board, shape);
      totalPlacements += n;
      if (n > 0) {
        shapesOk++;
      }
    }

    final danger =
        occ >= dangerOccupancy || totalPlacements < dangerTotalPlacements;

    return BoardAnalysis(
      occupancy: occ,
      emptyCells: empty,
      nearFullRowCount: nearRows,
      nearFullColCount: nearCols,
      fragmentedHoleScore: frag,
      largestEmptyRegion: largestRegion,
      totalLegalPlacements: totalPlacements,
      shapesWithAnyPlacement: shapesOk,
      isDanger: danger,
    );
  }

  /// Number of distinct (originX, originY) where [shape] fits on [board].
  static int legalPlacementCount(BoardState board, BlockShape shape) {
    final n = board.size;
    var c = 0;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (board.canPlace(shape: shape, originX: x, originY: y)) {
          c++;
        }
      }
    }
    return c;
  }

  /// True if at least one shape in [shapes] can be placed somewhere on [board].
  static bool queueHasAnyLegalMove(BoardState board, List<BlockShape> shapes) {
    for (final shape in shapes) {
      if (legalPlacementCount(board, shape) > 0) {
        return true;
      }
    }
    return false;
  }

  /// Count of queue items that have at least one legal placement.
  static int usableShapeCount(BoardState board, List<BlockShape> shapes) {
    var u = 0;
    for (final shape in shapes) {
      if (legalPlacementCount(board, shape) > 0) {
        u++;
      }
    }
    return u;
  }
}
