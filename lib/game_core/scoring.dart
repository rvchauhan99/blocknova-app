import 'scoring_config.dart';

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.total,
    required this.basePlacement,
    required this.clearBonus,
    required this.comboBonus,
    required this.streakBonus,
  });

  final int total;
  final int basePlacement;
  final int clearBonus;
  final int comboBonus;
  final int streakBonus;
}

ScoreBreakdown computeMoveScore({
  required int placedTileCount,
  required int clearedLines,
  required int comboCount,
  required int streakCount,
}) {
  final basePlacement = placedTileCount * ScoringConfig.placementPointPerTile;
  final clearBonus = clearedLines * ScoringConfig.lineClearBonus;
  final baseMovePoints = basePlacement + clearBonus;

  final comboStep = comboCount <= 1
      ? 0
      : (comboCount - 1).clamp(0, ScoringConfig.comboCap);
  final comboBonus =
      (baseMovePoints * comboStep * ScoringConfig.comboPercentPerStep) ~/ 100;

  final streakStep = streakCount <= 1
      ? 0
      : (streakCount - 1).clamp(0, ScoringConfig.streakCap);
  final streakBonus = streakStep * ScoringConfig.streakFlatPerStep;

  final total = baseMovePoints + comboBonus + streakBonus;
  return ScoreBreakdown(
    total: total,
    basePlacement: basePlacement,
    clearBonus: clearBonus,
    comboBonus: comboBonus,
    streakBonus: streakBonus,
  );
}
