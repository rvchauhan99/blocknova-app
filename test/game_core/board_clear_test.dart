import 'package:blocknova_app/game_core/block_shape.dart';
import 'package:blocknova_app/game_core/board_state.dart';
import 'package:blocknova_app/game_core/grid_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Simultaneous row+column clear is detected and applied', () {
    var board = const BoardState(size: 8);
    const single = BlockShape(colorType: BlockColorType.purple, id: 'single', cells: [GridPoint(0, 0)]);

    // Fill row 0 except (7,0)
    for (var x = 0; x < 7; x++) {
      board = board.place(shape: single, originX: x, originY: 0);
    }
    // Fill column 7 except (7,0)
    for (var y = 1; y < 8; y++) {
      board = board.place(shape: single, originX: 7, originY: y);
    }

    // Final placement completes both row 0 and column 7.
    board = board.place(shape: single, originX: 7, originY: 0);
    final clear = board.clearCompletedLines();

    expect(clear.clearedRows, contains(0));
    expect(clear.clearedCols, contains(7));
    expect(clear.clearedLineCount, 2);
    expect(clear.board.occupied.isEmpty, isTrue);
  });
}
