/// Balanced scoring profile for Stage 3 (line-clear-only).
abstract final class ScoringConfig {
  /// Base points per placed tile.
  static const int placementPointPerTile = 5;

  /// Bonus points per cleared line (row or column).
  static const int lineClearBonus = 40;

  /// Maximum combo multiplier bonus steps.
  static const int comboCap = 5;

  /// Combo bonus is applied as a percent multiplier over move points.
  /// e.g. combo=2 => +10%, combo=3 => +20%, capped by [comboCap].
  static const int comboPercentPerStep = 10;

  /// Consecutive clear streak cap.
  static const int streakCap = 6;

  /// Flat bonus per streak step (starting from streak 2).
  static const int streakFlatPerStep = 4;
}
