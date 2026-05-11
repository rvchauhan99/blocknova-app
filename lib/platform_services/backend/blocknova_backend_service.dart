import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper for BlockNova HTTPS callables (see repo `API_CONTRACT.md`).
class BlocknovaBackendService {
  BlocknovaBackendService({FirebaseFunctions? functions})
      : _functions = functions ??
            (Firebase.apps.isNotEmpty
                ? FirebaseFunctions.instanceFor(region: 'us-central1')
                : null);

  final FirebaseFunctions? _functions;

  bool get isAvailable => _functions != null;

  Future<List<LeaderboardEntryDto>> getLeaderboard({int limit = 20}) async {
    final fn = _functions;
    if (fn == null) {
      throw StateError('Firebase not initialized');
    }
    final callable = fn.httpsCallable('getLeaderboard');
    final payload = <String, dynamic>{
      'mode': 'endless',
      'limit': limit,
    };
    final result = await callable.call(payload);
    final top = result.data;
    if (top is! Map) {
      return <LeaderboardEntryDto>[];
    }
    final data = Map<String, dynamic>.from(top);
    final raw = data['entries'];
    if (raw is! List) {
      return <LeaderboardEntryDto>[];
    }
    final out = <LeaderboardEntryDto>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final m = Map<String, dynamic>.from(item);
      out.add(
        LeaderboardEntryDto(
          uid: '${m['uid'] ?? ''}',
          displayName: m['displayName']?.toString(),
          score: (m['score'] is num) ? (m['score'] as num).toInt() : int.tryParse('${m['score']}') ?? 0,
          rank: (m['rank'] is num) ? (m['rank'] as num).toInt() : int.tryParse('${m['rank']}') ?? 0,
        ),
      );
    }
    return out;
  }

  Future<SubmitRunResultDto> submitRun({
    required String runId,
    required String mode,
    required int score,
    required int durationSec,
    required int moves,
  }) async {
    final fn = _functions;
    if (fn == null) {
      throw StateError('Firebase not initialized');
    }
    final callable = fn.httpsCallable('submitRun');
    final payload = <String, dynamic>{
      'runId': runId,
      'mode': mode,
      'score': score,
      'durationSec': durationSec,
      'moves': moves,
    };
    try {
      final result = await callable.call(payload);
      final raw = result.data;
      if (raw is! Map) {
        return const SubmitRunResultDto(accepted: false, reason: 'empty_response', bestScoreUpdated: false);
      }
      final data = Map<String, dynamic>.from(raw);
      return SubmitRunResultDto(
        accepted: data['accepted'] == true,
        reason: data['reason']?.toString(),
        bestScoreUpdated: data['bestScoreUpdated'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('submitRun failed: ${e.code} ${e.message}');
      return SubmitRunResultDto(
        accepted: false,
        reason: e.code,
        bestScoreUpdated: false,
      );
    }
  }
}

class LeaderboardEntryDto {
  const LeaderboardEntryDto({
    required this.uid,
    this.displayName,
    required this.score,
    required this.rank,
  });

  final String uid;
  final String? displayName;
  final int score;
  final int rank;
}

class SubmitRunResultDto {
  const SubmitRunResultDto({
    required this.accepted,
    this.reason,
    required this.bestScoreUpdated,
  });

  final bool accepted;
  final String? reason;
  final bool bestScoreUpdated;
}
