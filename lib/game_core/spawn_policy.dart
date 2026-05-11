import 'dart:math';

import 'board_analysis.dart';
import 'block_queue.dart';
import 'block_shape.dart';
import 'board_state.dart';

/// Bands used to tune spawn weights (not strict stages).
enum SpawnProgressionBand { opening, mid, late }

/// Board-aware queue generation: solvability checks, weighting, recovery.
abstract final class BlockSpawnPolicy {
  static const int _maxRandomAttempts = 96;
  static const int _openingRefillCap = 2;
  static const int _midOccupancy = 22;
  static const int _lateOccupancy = 34;
  static const int _openingMediumOccupancyCap = 12;

  /// Shapes with at most 3 cells — easier to place when the board is tight.
  static final List<BlockShape> kRecoveryBiasPool = kShapePool
      .where((s) => s.tileCount <= 3)
      .toList();

  /// Small shapes without monomino (recovery variety).
  static final List<BlockShape> kRecoverySmallNoSingle = kShapePool
      .where((s) => s.tileCount <= 3 && s.id != 'single')
      .toList();

  /// Small shapes for exhaustive fallback (<=3 tiles).
  static final List<BlockShape> kSmallPool = kShapePool
      .where((s) => s.tileCount <= 3)
      .toList();

  static final BlockShape kSingle = kShapePool.firstWhere(
    (s) => s.id == 'single',
  );

  /// First tray or after refills. [queueRefillCount] is 0 for the initial 3-pack before any
  /// placement; increments each time a new full tray of 3 is dealt after the previous tray emptied.
  static BlockQueue dealQueue({
    required BoardState board,
    required Random rng,
    required int queueRefillCount,
  }) {
    final analysis = BoardAnalysis.fromBoard(board);
    final band = _bandFor(refillCount: queueRefillCount, analysis: analysis);
    final danger = analysis.isDanger;
    BlockQueue? best;
    var bestScore = -1 << 30;
    for (var attempt = 0; attempt < _maxRandomAttempts; attempt++) {
      final a = _weightedPickShape(rng, band, danger: danger);
      final b = _weightedPickShape(rng, band, danger: danger);
      final c = _weightedPickShape(rng, band, danger: danger);
      var hand = <BlockShape>[a, b, c];
      hand = _maybeInjectOpeningMedium(
        board: board,
        band: band,
        analysis: analysis,
        rng: rng,
        hand: hand,
      );
      if (!_passesSolvability(board, hand)) {
        continue;
      }
      if (!_passesProgressionRules(analysis, band, hand)) {
        continue;
      }
      if (!_passesVarietyRules(analysis, hand, maxSingles: 1)) {
        continue;
      }
      final score = _puzzleHandScore(board, analysis, band, hand);
      if (score > bestScore) {
        bestScore = score;
        best = BlockQueue(hand);
      }
    }
    if (best != null) {
      return best;
    }
    return BlockQueue(_exhaustiveFallback(board, rng));
  }

  /// Rewarded continue: must guarantee at least one legal placement on current board.
  static BlockQueue dealRecoveryQueue({
    required BoardState board,
    required Random rng,
  }) {
    final analysis = BoardAnalysis.fromBoard(board);
    final danger = analysis.isDanger;
    BlockQueue? best;
    var bestScore = -1 << 30;
    for (var attempt = 0; attempt < _maxRandomAttempts; attempt++) {
      final a = _pickRecoveryShape(rng, danger: danger);
      final b = _pickRecoveryShape(rng, danger: danger);
      final c = _pickRecoveryShape(rng, danger: danger);
      final hand = <BlockShape>[a, b, c];
      if (!_passesSolvability(board, hand)) {
        continue;
      }
      if (!_passesRecoveryAntiFrustration(board, analysis, hand)) {
        continue;
      }
      if (!_passesVarietyRules(analysis, hand, maxSingles: danger ? 2 : 1)) {
        continue;
      }
      final score = _puzzleHandScore(board, analysis, SpawnProgressionBand.late, hand);
      if (score > bestScore) {
        bestScore = score;
        best = BlockQueue(hand);
      }
    }
    if (best != null) {
      return best;
    }
    return BlockQueue(_exhaustiveFallback(board, rng));
  }

  /// Max lattice-aligned placements on an empty [boardSize] square (upper bound for normalization).
  static int maxLatticePlacements(BlockShape shape, int boardSize) {
    var minDx = 0;
    var maxDx = 0;
    var minDy = 0;
    var maxDy = 0;
    for (final c in shape.cells) {
      if (c.dx < minDx) {
        minDx = c.dx;
      }
      if (c.dx > maxDx) {
        maxDx = c.dx;
      }
      if (c.dy < minDy) {
        minDy = c.dy;
      }
      if (c.dy > maxDy) {
        maxDy = c.dy;
      }
    }
    final w = maxDx - minDx + 1;
    final h = maxDy - minDy + 1;
    final xSpan = boardSize - w + 1;
    final ySpan = boardSize - h + 1;
    if (xSpan <= 0 || ySpan <= 0) {
      return 0;
    }
    return xSpan * ySpan;
  }

  /// Composite score: normalized placement utility, variety, size mix; not dominated by monominos.
  static int _puzzleHandScore(
    BoardState board,
    BoardAnalysis analysis,
    SpawnProgressionBand band,
    List<BlockShape> hand,
  ) {
    final n = board.size;
    var placementPart = 0;
    for (final shape in hand) {
      final legal = BoardAnalysis.legalPlacementCount(board, shape);
      final cap = max(1, maxLatticePlacements(shape, n));
      placementPart += (1000 * legal) ~/ cap;
    }

    final ids = hand.map((s) => s.id).toSet();
    final varietyBonus = ids.length * 85;

    var dupPenalty = 0;
    for (final s in hand) {
      final nSame = hand.where((x) => x.id == s.id).length;
      if (nSame > 1) {
        dupPenalty += (nSame - 1) * 40;
      }
    }

    var sizeMix = 0;
    if (band != SpawnProgressionBand.opening &&
        hand.any((s) => s.tileCount >= 4 && s.tileCount < 9)) {
      sizeMix = 140;
    }

    final tie = analysis.nearFullRowCount + analysis.nearFullColCount;
    return placementPart + varietyBonus - dupPenalty + sizeMix + tie;
  }

  static bool _passesVarietyRules(
    BoardAnalysis analysis,
    List<BlockShape> hand, {
    required int maxSingles,
  }) {
    final singles = hand.where((s) => s.id == 'single').length;
    return singles <= maxSingles;
  }

  static List<BlockShape> _maybeInjectOpeningMedium({
    required BoardState board,
    required SpawnProgressionBand band,
    required BoardAnalysis analysis,
    required Random rng,
    required List<BlockShape> hand,
  }) {
    if (band != SpawnProgressionBand.opening) {
      return hand;
    }
    if (analysis.occupancy > _openingMediumOccupancyCap) {
      return hand;
    }
    if (hand.any((s) => s.tileCount >= 3 && s.tileCount <= 4)) {
      return hand;
    }
    final mediums = kShapePool
        .where((s) => s.tileCount >= 3 && s.tileCount <= 4)
        .toList();
    if (mediums.isEmpty) {
      return hand;
    }
    final next = hand.toList();
    next[rng.nextInt(3)] = mediums[rng.nextInt(mediums.length)];
    return next;
  }

  static int _weightForShape(BlockShape s, SpawnProgressionBand band, {required bool danger}) {
    final t = s.tileCount;
    if (s.id == 'single') {
      if (danger) {
        return 16;
      }
      switch (band) {
        case SpawnProgressionBand.opening:
          return 5;
        case SpawnProgressionBand.mid:
          return 4;
        case SpawnProgressionBand.late:
          return 3;
      }
    }
    if (t == 2) {
      return 14;
    }
    if (t == 3) {
      return 15;
    }
    if (t == 4) {
      return 14;
    }
    if (t == 5) {
      return 11;
    }
    if (t >= 9) {
      return band == SpawnProgressionBand.opening ? 0 : 3;
    }
    return 11;
  }

  static BlockShape _weightedPickShape(
    Random rng,
    SpawnProgressionBand band, {
    required bool danger,
  }) {
    var total = 0;
    final weights = <int>[];
    for (final s in kShapePool) {
      final w = _weightForShape(s, band, danger: danger);
      weights.add(w);
      total += w;
    }
    if (total <= 0) {
      return kShapePool[rng.nextInt(kShapePool.length)];
    }
    var r = rng.nextInt(total);
    for (var i = 0; i < kShapePool.length; i++) {
      r -= weights[i];
      if (r < 0) {
        return kShapePool[i];
      }
    }
    return kShapePool.last;
  }

  static int _weightRecoveryShape(BlockShape s, {required bool danger}) {
    if (s.id == 'single') {
      return danger ? 16 : 4;
    }
    final t = s.tileCount;
    if (t == 2) {
      return 14;
    }
    if (t == 3) {
      return 14;
    }
    return 10;
  }

  static BlockShape _pickRecoveryShape(Random rng, {required bool danger}) {
    final pool = kRecoveryBiasPool;
    var total = 0;
    final weights = <int>[];
    for (final s in pool) {
      final w = _weightRecoveryShape(s, danger: danger);
      weights.add(w);
      total += w;
    }
    if (total <= 0) {
      return pool[rng.nextInt(pool.length)];
    }
    var r = rng.nextInt(total);
    for (var i = 0; i < pool.length; i++) {
      r -= weights[i];
      if (r < 0) {
        return pool[i];
      }
    }
    return pool.last;
  }

  static SpawnProgressionBand _bandFor({
    required int refillCount,
    required BoardAnalysis analysis,
  }) {
    if (refillCount <= _openingRefillCap) {
      return SpawnProgressionBand.opening;
    }
    if (analysis.occupancy >= _lateOccupancy) {
      return SpawnProgressionBand.late;
    }
    if (analysis.occupancy >= _midOccupancy) {
      return SpawnProgressionBand.mid;
    }
    return SpawnProgressionBand.opening;
  }

  static bool _passesSolvability(BoardState board, List<BlockShape> hand) {
    if (!BoardAnalysis.queueHasAnyLegalMove(board, hand)) {
      return false;
    }
    final usable = BoardAnalysis.usableShapeCount(board, hand);
    if (usable < 2) {
      return false;
    }
    return true;
  }

  static bool _passesRecoveryAntiFrustration(
    BoardState board,
    BoardAnalysis analysis,
    List<BlockShape> hand,
  ) {
    final large = hand.where((s) => s.tileCount >= 5).length;
    if (analysis.isDanger && large >= 2) {
      return false;
    }
    if (analysis.isDanger && hand.every((s) => s.tileCount >= 4)) {
      return false;
    }
    if (!hand.any((s) => s.tileCount <= 3)) {
      return false;
    }
    return true;
  }

  static bool _passesProgressionRules(
    BoardAnalysis analysis,
    SpawnProgressionBand band,
    List<BlockShape> hand,
  ) {
    final large = hand.where((s) => s.tileCount >= 5).length;
    final huge = hand.where((s) => s.tileCount >= 9).length;

    if (analysis.isDanger) {
      if (hand.every((s) => s.tileCount >= 4)) {
        return false;
      }
      if (!hand.any((s) => s.tileCount <= 3)) {
        return false;
      }
      if (large >= 2) {
        return false;
      }
    }

    switch (band) {
      case SpawnProgressionBand.opening:
        if (large > 1) {
          return false;
        }
        if (!hand.any((s) => s.tileCount <= 3)) {
          return false;
        }
        if (huge > 0) {
          return false;
        }
        break;
      case SpawnProgressionBand.mid:
        if (large > 2) {
          return false;
        }
        break;
      case SpawnProgressionBand.late:
        if (large > 2) {
          return false;
        }
        break;
    }

    return true;
  }

  /// Guaranteed playable; prefers ≤1 single, then ≤2 singles, then triple single.
  static List<BlockShape> _exhaustiveFallback(BoardState board, Random rng) {
    final boardAnalysis = BoardAnalysis.fromBoard(board);
    for (var attempt = 0; attempt < 500; attempt++) {
      final a = kSmallPool[rng.nextInt(kSmallPool.length)];
      final b = kSmallPool[rng.nextInt(kSmallPool.length)];
      final c = kSmallPool[rng.nextInt(kSmallPool.length)];
      var hand = <BlockShape>[a, b, c];
      hand.shuffle(rng);
      if (_passesVarietyRules(boardAnalysis, hand, maxSingles: 1) &&
          _passesSolvability(board, hand)) {
        return hand;
      }
    }

    for (final a in kSmallPool) {
      for (final b in kSmallPool) {
        for (final c in kSmallPool) {
          final hand = <BlockShape>[a, b, c];
          if (_passesVarietyRules(boardAnalysis, hand, maxSingles: 1) &&
              _passesSolvability(board, hand)) {
            return hand;
          }
        }
      }
    }

    for (final a in kSmallPool) {
      for (final b in kSmallPool) {
        for (final c in kSmallPool) {
          final hand = <BlockShape>[a, b, c];
          if (_passesVarietyRules(boardAnalysis, hand, maxSingles: 2) &&
              _passesSolvability(board, hand)) {
            return hand;
          }
        }
      }
    }

    final single = kSingle;
    for (var attempt = 0; attempt < 200; attempt++) {
      final a = kRecoverySmallNoSingle.isEmpty
          ? kSmallPool[rng.nextInt(kSmallPool.length)]
          : kRecoverySmallNoSingle[rng.nextInt(kRecoverySmallNoSingle.length)];
      final b = kSmallPool[rng.nextInt(kSmallPool.length)];
      final hand = <BlockShape>[single, a, b]..shuffle(rng);
      if (_passesVarietyRules(boardAnalysis, hand, maxSingles: 1) &&
          _passesSolvability(board, hand)) {
        return hand;
      }
    }

    return <BlockShape>[single, single, single];
  }
}

