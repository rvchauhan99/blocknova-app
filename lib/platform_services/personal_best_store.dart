import 'package:shared_preferences/shared_preferences.dart';

/// Local endless-mode high score (device-only; server best stays on leaderboard).
abstract final class PersonalBestStore {
  static const String _key = 'blocknova_endless_personal_best_v1';

  static Future<int> read() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_key) ?? 0;
  }

  static Future<void> recordIfBetter(int score) async {
    if (score < 0) {
      return;
    }
    final p = await SharedPreferences.getInstance();
    final cur = p.getInt(_key) ?? 0;
    if (score > cur) {
      await p.setInt(_key, score);
    }
  }
}
