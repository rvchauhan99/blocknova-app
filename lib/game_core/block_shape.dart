import 'dart:math';
import 'grid_point.dart';

enum BlockColorType {
  red,
  green,
  blue,
  yellow,
  purple,
  orange,
  cyan,
}

class BlockShape {
  const BlockShape({
    required this.id,
    required this.cells,
    required this.colorType,
  });

  final String id;
  final List<GridPoint> cells;
  final BlockColorType colorType;

  int get tileCount => cells.length;
}

/// A comprehensive pool of standard Block Blast shapes.
const List<BlockShape> kShapePool = [
  // 1x1
  BlockShape(id: 'single', cells: [GridPoint(0, 0)], colorType: BlockColorType.purple),
  
  // Lines
  BlockShape(id: 'line_2_h', cells: [GridPoint(0, 0), GridPoint(1, 0)], colorType: BlockColorType.blue),
  BlockShape(id: 'line_2_v', cells: [GridPoint(0, 0), GridPoint(0, 1)], colorType: BlockColorType.blue),
  
  BlockShape(id: 'line_3_h', cells: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(2, 0)], colorType: BlockColorType.yellow),
  BlockShape(id: 'line_3_v', cells: [GridPoint(0, 0), GridPoint(0, 1), GridPoint(0, 2)], colorType: BlockColorType.yellow),
  
  BlockShape(id: 'line_4_h', cells: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(2, 0), GridPoint(3, 0)], colorType: BlockColorType.cyan),
  BlockShape(id: 'line_4_v', cells: [GridPoint(0, 0), GridPoint(0, 1), GridPoint(0, 2), GridPoint(0, 3)], colorType: BlockColorType.cyan),

  BlockShape(id: 'line_5_h', cells: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(2, 0), GridPoint(3, 0), GridPoint(4, 0)], colorType: BlockColorType.red),
  BlockShape(id: 'line_5_v', cells: [GridPoint(0, 0), GridPoint(0, 1), GridPoint(0, 2), GridPoint(0, 3), GridPoint(0, 4)], colorType: BlockColorType.red),

  // Squares
  BlockShape(id: 'square_2x2', cells: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(0, 1), GridPoint(1, 1)], colorType: BlockColorType.yellow),
  BlockShape(id: 'square_3x3', cells: [
    GridPoint(0, 0), GridPoint(1, 0), GridPoint(2, 0),
    GridPoint(0, 1), GridPoint(1, 1), GridPoint(2, 1),
    GridPoint(0, 2), GridPoint(1, 2), GridPoint(2, 2)
  ], colorType: BlockColorType.red),

  // L-Shapes (small 2x2 area)
  BlockShape(id: 'l_small_1', cells: [GridPoint(0, 0), GridPoint(0, 1), GridPoint(1, 1)], colorType: BlockColorType.orange),
  BlockShape(id: 'l_small_2', cells: [GridPoint(1, 0), GridPoint(1, 1), GridPoint(0, 1)], colorType: BlockColorType.orange),
  BlockShape(id: 'l_small_3', cells: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(0, 1)], colorType: BlockColorType.orange),
  BlockShape(id: 'l_small_4', cells: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(1, 1)], colorType: BlockColorType.orange),

  // L-Shapes (large 3x3 area)
  BlockShape(id: 'l_large_1', cells: [GridPoint(0, 0), GridPoint(0, 1), GridPoint(0, 2), GridPoint(1, 2), GridPoint(2, 2)], colorType: BlockColorType.blue),
  BlockShape(id: 'l_large_2', cells: [GridPoint(2, 0), GridPoint(2, 1), GridPoint(2, 2), GridPoint(1, 2), GridPoint(0, 2)], colorType: BlockColorType.blue),
  BlockShape(id: 'l_large_3', cells: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(2, 0), GridPoint(0, 1), GridPoint(0, 2)], colorType: BlockColorType.blue),
  BlockShape(id: 'l_large_4', cells: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(2, 0), GridPoint(2, 1), GridPoint(2, 2)], colorType: BlockColorType.blue),

  // T-Shapes
  BlockShape(id: 't_shape_1', cells: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(2, 0), GridPoint(1, 1)], colorType: BlockColorType.purple),
  BlockShape(id: 't_shape_2', cells: [GridPoint(1, 0), GridPoint(0, 1), GridPoint(1, 1), GridPoint(2, 1)], colorType: BlockColorType.purple),
  BlockShape(id: 't_shape_3', cells: [GridPoint(0, 0), GridPoint(0, 1), GridPoint(0, 2), GridPoint(1, 1)], colorType: BlockColorType.purple),
  BlockShape(id: 't_shape_4', cells: [GridPoint(1, 0), GridPoint(1, 1), GridPoint(1, 2), GridPoint(0, 1)], colorType: BlockColorType.purple),

  // Z/S Shapes
  BlockShape(id: 'z_shape_1', cells: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(1, 1), GridPoint(2, 1)], colorType: BlockColorType.green),
  BlockShape(id: 'z_shape_2', cells: [GridPoint(1, 0), GridPoint(1, 1), GridPoint(0, 1), GridPoint(0, 2)], colorType: BlockColorType.green),
  BlockShape(id: 's_shape_1', cells: [GridPoint(1, 0), GridPoint(2, 0), GridPoint(0, 1), GridPoint(1, 1)], colorType: BlockColorType.green),
  BlockShape(id: 's_shape_2', cells: [GridPoint(0, 0), GridPoint(0, 1), GridPoint(1, 1), GridPoint(1, 2)], colorType: BlockColorType.green),
];

BlockShape getRandomShape(Random rng) {
  return kShapePool[rng.nextInt(kShapePool.length)];
}
