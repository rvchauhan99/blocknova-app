import 'dart:math';

import 'board_analysis.dart';
import 'block_queue.dart';
import 'block_shape.dart';
import 'board_state.dart';

/// Bands used to tune spawn weights (not strict stages).
enum SpawnProgressionBand { opening, mid, late }

/// Board-aware queue generation: solvability checks, weighting, recovery.
abstract final class BlockSpawnPolicy {
  static const int _maxRandomAttempts = 160;
  static const int _openingRefillCap = 2;
  static const int _midOccupancy = 22;
  static const int _lateOccupancy = 34;
  static const int _openingMediumOccupancyCap = 12;

  static final BlockShape kSingle = kShapePool.firstWhere(
    (s) => s.id == 'single',
  );

  static final List<BlockShape> _smallPool = kShapePool
      .where((s) => s.tileCount <= 3)
      .toList(growable: false);

  static final List<BlockShape> _compactPool = kShapePool
      .where((s) => s.tileCount <= 4)
      .toList(growable: false);

  /// First tray or after refills. [queueRefillCount] is 0 for the initial 3-pack before any
  /// placement; increments each time a new full tray of 3 is dealt after the previous tray emptied.
  static BlockQueue dealQueue({
    required BoardState board,
    required Random rng,
    required int queueRefillCount,
  }) {
    final context = _SpawnContext.normal(
      board: board,
      rng: rng,
      queueRefillCount: queueRefillCount,
    );
    return BlockQueue(_dealBestTray(context));
  }

  /// Rewarded continue: must guarantee at least one legal placement on current board.
  static BlockQueue dealRecoveryQueue({
    required BoardState board,
    required Random rng,
  }) {
    final context = _SpawnContext.recovery(board: board, rng: rng);
    return BlockQueue(_dealBestTray(context));
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

  static List<BlockShape> _dealBestTray(_SpawnContext context) {
    List<BlockShape>? best;
    var bestScore = -1 << 30;

    for (var attempt = 0; attempt < _maxRandomAttempts; attempt++) {
      final hand = _generateCandidate(context);
      if (!_passesHardFilters(context, hand)) {
        continue;
      }
      final score = _scoreTray(context, hand);
      if (score > bestScore) {
        bestScore = score;
        best = hand;
      }
    }

    return best ?? _exhaustiveFallback(context);
  }

  static List<BlockShape> _generateCandidate(_SpawnContext context) {
    var hand = <BlockShape>[
      _weightedPickShape(context),
      _weightedPickShape(context),
      _weightedPickShape(context),
    ];
    hand = _maybeInjectOpeningMedium(context, hand);
    hand.shuffle(context.rng);
    return hand;
  }

  static List<BlockShape> _maybeInjectOpeningMedium(
    _SpawnContext context,
    List<BlockShape> hand,
  ) {
    if (context.recovery || context.band != SpawnProgressionBand.opening) {
      return hand;
    }
    if (context.analysis.occupancy > _openingMediumOccupancyCap) {
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
    next[context.rng.nextInt(3)] = mediums[context.rng.nextInt(mediums.length)];
    return next;
  }

  static BlockShape _weightedPickShape(_SpawnContext context) {
    final pool = context.recovery ? _compactPool : kShapePool;
    var total = 0;
    final weights = <int>[];
    for (final shape in pool) {
      final w = _weightForShape(context, shape);
      weights.add(w);
      total += w;
    }
    if (total <= 0) {
      return pool[context.rng.nextInt(pool.length)];
    }

    var roll = context.rng.nextInt(total);
    for (var i = 0; i < pool.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        return pool[i];
      }
    }
    return pool.last;
  }

  static int _weightForShape(_SpawnContext context, BlockShape s) {
    final t = s.tileCount;
    final danger = context.analysis.isDanger;

    if (s.id == 'single') {
      if (context.recovery) {
        return danger ? 22 : 7;
      }
      switch (context.band) {
        case SpawnProgressionBand.opening:
          return 4;
        case SpawnProgressionBand.mid:
          return danger ? 12 : 3;
        case SpawnProgressionBand.late:
          return danger ? 14 : 2;
      }
    }

    if (context.recovery) {
      if (t == 2) {
        return danger ? 18 : 15;
      }
      if (t == 3) {
        return danger ? 16 : 15;
      }
      if (t == 4) {
        return danger ? 6 : 10;
      }
      return 0;
    }

    if (t == 2) {
      return danger ? 18 : 13;
    }
    if (t == 3) {
      return danger ? 17 : 15;
    }
    if (t == 4) {
      return danger ? 8 : 15;
    }
    if (t == 5) {
      return switch (context.band) {
        SpawnProgressionBand.opening => danger ? 2 : 8,
        SpawnProgressionBand.mid => danger ? 5 : 13,
        SpawnProgressionBand.late => danger ? 4 : 10,
      };
    }
    if (t >= 9) {
      if (danger || context.band == SpawnProgressionBand.opening) {
        return 0;
      }
      return context.band == SpawnProgressionBand.mid ? 2 : 1;
    }
    return 11;
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

  static bool _passesHardFilters(_SpawnContext context, List<BlockShape> hand) {
    final analysis = context.analysis;
    if (hand.length != 3) {
      return false;
    }
    if (!_queueHasAnyLegalMove(context, hand)) {
      return false;
    }
    if (_usableShapeCount(context, hand) < 2) {
      return false;
    }
    if (_singleCount(hand) > context.maxSingles) {
      return false;
    }

    final hasSmall = hand.any((s) => s.tileCount <= 3);
    final large = hand.where((s) => s.tileCount >= 5).length;
    final huge = hand.where((s) => s.tileCount >= 9).length;

    if (analysis.isDanger) {
      if (!hasSmall) {
        return false;
      }
      if (hand.every((s) => s.tileCount >= 4)) {
        return false;
      }
      if (large >= 2) {
        return false;
      }
    }

    if (context.recovery) {
      if (!hasSmall) {
        return false;
      }
      if (large > 0) {
        return false;
      }
      if (analysis.isDanger && hand.every((s) => s.tileCount >= 4)) {
        return false;
      }
      return true;
    }

    switch (context.band) {
      case SpawnProgressionBand.opening:
        if (large > 1) {
          return false;
        }
        if (huge > 0) {
          return false;
        }
        if (!hasSmall) {
          return false;
        }
        if (analysis.occupancy <= _openingMediumOccupancyCap &&
            !hand.any((s) => s.tileCount >= 3 && s.tileCount <= 4)) {
          return false;
        }
        break;
      case SpawnProgressionBand.mid:
      case SpawnProgressionBand.late:
        if (large > 2) {
          return false;
        }
        break;
    }

    return true;
  }

  static int _scoreTray(_SpawnContext context, List<BlockShape> hand) {
    final analysis = context.analysis;
    final board = context.board;
    final legalCounts = [
      for (final shape in hand) _legalPlacementCount(context, shape),
    ];
    final usable = legalCounts.where((n) => n > 0).length;
    final small = hand.where((s) => s.tileCount <= 3).length;
    final medium = hand
        .where((s) => s.tileCount >= 4 && s.tileCount <= 5)
        .length;
    final large = hand.where((s) => s.tileCount >= 5).length;
    final huge = hand.where((s) => s.tileCount >= 9).length;

    var score = usable * 2200;
    for (var i = 0; i < hand.length; i++) {
      final cap = max(1, maxLatticePlacements(hand[i], board.size));
      score += (1000 * legalCounts[i]) ~/ cap;
    }

    score += hand.map((s) => s.id).toSet().length * 170;
    score -= _duplicatePenalty(hand);

    final linePotential = _bestLineClearPotential(context, hand);
    final linePressure = analysis.nearFullRowCount + analysis.nearFullColCount;
    score += linePotential * (linePressure > 0 ? 520 : 260);

    if (small >= 1 && medium >= 1) {
      score += 280;
    }
    if (!context.recovery &&
        context.band != SpawnProgressionBand.opening &&
        large == 1) {
      score += 180;
    }
    if (!context.recovery &&
        context.band != SpawnProgressionBand.opening &&
        small == 3) {
      score -= 260;
    }
    if (context.band == SpawnProgressionBand.opening && medium >= 1) {
      score += 230;
    }
    if (context.band == SpawnProgressionBand.opening && large > 0) {
      score -= large * 120;
    }
    if (analysis.isDanger || context.recovery) {
      score += small * 260;
      score -= large * 520;
      score -= huge * 900;
    }
    if (analysis.disconnectedEmptyCells >= 6) {
      score += small * 180;
      score += hand.where((s) => s.tileCount == 4).length * 70;
      score -= large * 180;
    }
    if (_singleCount(hand) > 0 && !analysis.isDanger && !context.recovery) {
      score -= 100;
    }

    // Keep seeded runs stable while avoiding same-score bias toward pool order.
    score += context.rng.nextInt(17);
    return score;
  }

  static int _bestLineClearPotential(
    _SpawnContext context,
    List<BlockShape> hand,
  ) {
    var best = 0;
    for (final shape in hand) {
      final clears = context.lineClearPotential[shape.id] ?? 0;
      if (clears > best) {
        best = clears;
      }
    }
    return best;
  }

  static int _duplicatePenalty(List<BlockShape> hand) {
    var penalty = 0;
    final seen = <String, int>{};
    for (final shape in hand) {
      final count = (seen[shape.id] ?? 0) + 1;
      seen[shape.id] = count;
      if (count > 1) {
        penalty += count * 90;
      }
    }
    return penalty;
  }

  static int _singleCount(List<BlockShape> hand) {
    return hand.where((s) => s.id == 'single').length;
  }

  /// Guaranteed playable fallback; relaxes single limits only when the board leaves no better tray.
  static List<BlockShape> _exhaustiveFallback(_SpawnContext context) {
    final pools = context.recovery || context.analysis.isDanger
        ? <List<BlockShape>>[_compactPool, _smallPool]
        : <List<BlockShape>>[kShapePool, _compactPool, _smallPool];

    for (final pool in pools) {
      final best = _bestFromPool(
        context: context,
        pool: pool,
        maxSingles: context.maxSingles,
        minUsable: 2,
        enforceProgression: true,
      );
      if (best != null) {
        return best;
      }
    }

    for (final pool in [_compactPool, _smallPool]) {
      final best = _bestFromPool(
        context: context,
        pool: pool,
        maxSingles: 2,
        minUsable: 2,
        enforceProgression: false,
      );
      if (best != null) {
        return best;
      }
    }

    for (final pool in [_smallPool]) {
      final best = _bestFromPool(
        context: context,
        pool: pool,
        maxSingles: 3,
        minUsable: 1,
        enforceProgression: false,
      );
      if (best != null) {
        return best;
      }
    }

    return <BlockShape>[kSingle, kSingle, kSingle];
  }

  static List<BlockShape>? _bestFromPool({
    required _SpawnContext context,
    required List<BlockShape> pool,
    required int maxSingles,
    required int minUsable,
    required bool enforceProgression,
  }) {
    List<BlockShape>? best;
    var bestScore = -1 << 30;
    for (final a in pool) {
      for (final b in pool) {
        for (final c in pool) {
          final hand = <BlockShape>[a, b, c];
          if (_singleCount(hand) > maxSingles) {
            continue;
          }
          if (!_queueHasAnyLegalMove(context, hand)) {
            continue;
          }
          if (_usableShapeCount(context, hand) < minUsable) {
            continue;
          }
          if (enforceProgression &&
              !_passesFallbackProgression(context, hand)) {
            continue;
          }
          final score = _scoreTray(context, hand);
          if (score > bestScore) {
            bestScore = score;
            best = hand;
          }
        }
      }
    }
    if (best == null) {
      return null;
    }
    final next = best.toList()..shuffle(context.rng);
    return next;
  }

  static bool _passesFallbackProgression(
    _SpawnContext context,
    List<BlockShape> hand,
  ) {
    final analysis = context.analysis;
    final large = hand.where((s) => s.tileCount >= 5).length;
    final hasSmall = hand.any((s) => s.tileCount <= 3);
    if ((analysis.isDanger || context.recovery) && !hasSmall) {
      return false;
    }
    if ((analysis.isDanger || context.recovery) && large >= 2) {
      return false;
    }
    if (context.band == SpawnProgressionBand.opening && large > 1) {
      return false;
    }
    return true;
  }

  static bool _queueHasAnyLegalMove(
    _SpawnContext context,
    List<BlockShape> hand,
  ) {
    return hand.any((shape) => _legalPlacementCount(context, shape) > 0);
  }

  static int _usableShapeCount(_SpawnContext context, List<BlockShape> hand) {
    var count = 0;
    for (final shape in hand) {
      if (_legalPlacementCount(context, shape) > 0) {
        count++;
      }
    }
    return count;
  }

  static int _legalPlacementCount(_SpawnContext context, BlockShape shape) {
    return context.legalPlacements[shape.id] ??
        BoardAnalysis.legalPlacementCount(context.board, shape);
  }

  static Map<String, int> _precomputeLegalPlacements(BoardState board) {
    return {
      for (final shape in kShapePool)
        shape.id: BoardAnalysis.legalPlacementCount(board, shape),
    };
  }

  static Map<String, int> _precomputeLineClearPotential(BoardState board) {
    final values = <String, int>{};
    for (final shape in kShapePool) {
      var best = 0;
      for (var y = 0; y < board.size; y++) {
        for (var x = 0; x < board.size; x++) {
          if (!board.canPlace(shape: shape, originX: x, originY: y)) {
            continue;
          }
          final clears = board
              .place(shape: shape, originX: x, originY: y)
              .clearCompletedLines()
              .clearedLineCount;
          if (clears > best) {
            best = clears;
          }
        }
      }
      values[shape.id] = best;
    }
    return values;
  }
}

class _SpawnContext {
  _SpawnContext._({
    required this.board,
    required this.rng,
    required this.analysis,
    required this.band,
    required this.recovery,
    required this.maxSingles,
    required this.legalPlacements,
    required this.lineClearPotential,
  });

  factory _SpawnContext.normal({
    required BoardState board,
    required Random rng,
    required int queueRefillCount,
  }) {
    final analysis = BoardAnalysis.fromBoard(board);
    return _SpawnContext._(
      board: board,
      rng: rng,
      analysis: analysis,
      band: BlockSpawnPolicy._bandFor(
        refillCount: queueRefillCount,
        analysis: analysis,
      ),
      recovery: false,
      maxSingles: 1,
      legalPlacements: BlockSpawnPolicy._precomputeLegalPlacements(board),
      lineClearPotential: BlockSpawnPolicy._precomputeLineClearPotential(board),
    );
  }

  factory _SpawnContext.recovery({
    required BoardState board,
    required Random rng,
  }) {
    final analysis = BoardAnalysis.fromBoard(board);
    return _SpawnContext._(
      board: board,
      rng: rng,
      analysis: analysis,
      band: SpawnProgressionBand.late,
      recovery: true,
      maxSingles: analysis.isDanger ? 2 : 1,
      legalPlacements: BlockSpawnPolicy._precomputeLegalPlacements(board),
      lineClearPotential: BlockSpawnPolicy._precomputeLineClearPotential(board),
    );
  }

  final BoardState board;
  final Random rng;
  final BoardAnalysis analysis;
  final SpawnProgressionBand band;
  final bool recovery;
  final int maxSingles;
  final Map<String, int> legalPlacements;
  final Map<String, int> lineClearPotential;
}
