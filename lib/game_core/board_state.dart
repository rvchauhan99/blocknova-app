import 'block_shape.dart';

class ClearResult {
  const ClearResult({
    required this.board,
    required this.clearedRows,
    required this.clearedCols,
  });

  final BoardState board;
  final List<int> clearedRows;
  final List<int> clearedCols;

  int get clearedLineCount => clearedRows.length + clearedCols.length;
}

class BoardState {
  const BoardState({
    this.size = 8,
    Map<int, BlockColorType>? cellColors,
  }) : cellColors = cellColors ?? const <int, BlockColorType>{};

  final int size;
  final Map<int, BlockColorType> cellColors;

  Set<int> get occupied => cellColors.keys.toSet();

  bool isInside(int x, int y) => x >= 0 && y >= 0 && x < size && y < size;

  int keyFor(int x, int y) => y * size + x;

  bool isOccupied(int x, int y) => cellColors.containsKey(keyFor(x, y));
  
  BlockColorType? colorAt(int x, int y) => cellColors[keyFor(x, y)];

  bool canPlace({
    required BlockShape shape,
    required int originX,
    required int originY,
  }) {
    for (final c in shape.cells) {
      final x = originX + c.dx;
      final y = originY + c.dy;
      if (!isInside(x, y)) {
        return false;
      }
      if (isOccupied(x, y)) {
        return false;
      }
    }
    return true;
  }

  BoardState place({
    required BlockShape shape,
    required int originX,
    required int originY,
  }) {
    if (!canPlace(shape: shape, originX: originX, originY: originY)) {
      throw StateError('Invalid placement');
    }
    final next = Map<int, BlockColorType>.from(cellColors);
    for (final c in shape.cells) {
      final x = originX + c.dx;
      final y = originY + c.dy;
      next[keyFor(x, y)] = shape.colorType;
    }
    return BoardState(size: size, cellColors: next);
  }

  ClearResult clearCompletedLines() {
    final fullRows = <int>[];
    final fullCols = <int>[];

    for (var y = 0; y < size; y++) {
      var rowFull = true;
      for (var x = 0; x < size; x++) {
        if (!isOccupied(x, y)) {
          rowFull = false;
          break;
        }
      }
      if (rowFull) {
        fullRows.add(y);
      }
    }

    for (var x = 0; x < size; x++) {
      var colFull = true;
      for (var y = 0; y < size; y++) {
        if (!isOccupied(x, y)) {
          colFull = false;
          break;
        }
      }
      if (colFull) {
        fullCols.add(x);
      }
    }

    if (fullRows.isEmpty && fullCols.isEmpty) {
      return ClearResult(
        board: this,
        clearedRows: const [],
        clearedCols: const [],
      );
    }

    final next = Map<int, BlockColorType>.from(cellColors);
    for (final y in fullRows) {
      for (var x = 0; x < size; x++) {
        next.remove(keyFor(x, y));
      }
    }
    for (final x in fullCols) {
      for (var y = 0; y < size; y++) {
        next.remove(keyFor(x, y));
      }
    }

    return ClearResult(
      board: BoardState(size: size, cellColors: next),
      clearedRows: fullRows,
      clearedCols: fullCols,
    );
  }
}
