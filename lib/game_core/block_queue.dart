import 'dart:math';

import 'block_shape.dart';
import 'board_state.dart';
import 'spawn_policy.dart';

class BlockQueue {
  const BlockQueue(this.items);

  final List<BlockShape> items;

  /// Uniform random (legacy); prefer [BlockSpawnPolicy.dealQueue] for gameplay.
  factory BlockQueue.random(Random rng) {
    return BlockQueue([
      getRandomShape(rng),
      getRandomShape(rng),
      getRandomShape(rng),
    ]);
  }

  factory BlockQueue.stage2Starter() {
    final rng = Random();
    return BlockSpawnPolicy.dealQueue(
      board: const BoardState(size: 8),
      rng: rng,
      queueRefillCount: 0,
    );
  }

  bool get isEmpty => items.isEmpty;

  BlockShape? at(int index) {
    if (index < 0 || index >= items.length) {
      return null;
    }
    return items[index];
  }

  BlockQueue removeAt(int index) {
    if (index < 0 || index >= items.length) {
      return this;
    }
    final next = items.toList()..removeAt(index);
    return BlockQueue(next);
  }
}
