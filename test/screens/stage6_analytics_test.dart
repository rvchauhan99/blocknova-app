import 'package:blocknova_app/game_core/block_queue.dart';
import 'package:blocknova_app/game_core/block_shape.dart';
import 'package:blocknova_app/game_core/board_state.dart';
import 'package:blocknova_app/game_core/game_session.dart';
import 'package:blocknova_app/game_core/grid_point.dart';
import 'package:blocknova_app/platform_services/ads/ads_config.dart';
import 'package:blocknova_app/platform_services/ads/ads_service.dart';
import 'package:blocknova_app/platform_services/analytics/analytics_service.dart';
import 'package:blocknova_app/platform_services/audio_service.dart';
import 'package:blocknova_app/platform_services/haptics_service.dart';
import 'package:blocknova_app/screens/game_placeholder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SharedPreferences.setMockInitialValues(<String, Object>{});

  testWidgets('run lifecycle and screen_view game emit expected events', (tester) async {
    final recording = _RecordingAnalyticsService();
    final fakeAds = _FakeAdsService();

    await tester.pumpWidget(
      MaterialApp(
        home: Stage2BoardScreen(
          initialSession: _gameOverSession(),
          adsService: fakeAds,
          analyticsService: recording,
          audioService: StubAudioService(),
          hapticsService: _StubHaptics(),
        ),
      ),
    );
    await tester.pump();

    expect(
      recording.eventNames,
      containsAll(<String>['run_start', 'screen_view', 'continue_offer_shown']),
    );

    await tester.tap(find.text('END RUN'));
    // Flame [GameWidget] keeps the game loop scheduling frames; avoid pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(recording.eventNames, contains('run_end'));
    final runEnd = recording.lastParamsFor('run_end');
    expect(runEnd['end_reason'], 'no_moves');
    expect(runEnd['mode'], 'sandbox');
    expect(recording.eventNames.where((e) => e == 'run_start').length, greaterThanOrEqualTo(2));
  });
}

GameSession _gameOverSession() {
  final occupied = <int>{};
  const size = 8;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (x == 7 && y == 7) {
        continue;
      }
      occupied.add(y * size + x);
    }
  }
  return GameSession(
    board: BoardState(size: size, cellColors: { for (var k in occupied) k: BlockColorType.purple }),
    queue: const BlockQueue([
      BlockShape(colorType: BlockColorType.purple, 
        id: 'domino_h',
        cells: [GridPoint(0, 0), GridPoint(1, 0)],
      ),
    ]),
    selectedQueueIndex: 0,
    isGameOver: true,
  );
}

class _RecordingAnalyticsService implements AnalyticsService {
  final List<String> eventNames = <String>[];
  final List<Map<String, Object?>> eventParams = <Map<String, Object?>>[];

  Map<String, Object?> lastParamsFor(String name) {
    for (var i = eventNames.length - 1; i >= 0; i--) {
      if (eventNames[i] == name) {
        return Map<String, Object?>.from(eventParams[i]);
      }
    }
    throw StateError('No event named $name');
  }

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    eventNames.add(name);
    eventParams.add(Map<String, Object?>.from(parameters));
  }
}

class _FakeAdsService implements AdsService {
  @override
  Future<void> prepareInterstitial() async {}

  @override
  Future<void> prepareRewarded() async {}

  @override
  Future<RewardedShowResult> showRewardedContinue({void Function()? onRewardedAdImpression}) async {
    return const RewardedShowResult.failed(RewardedFailureCode.notLoaded);
  }

  @override
  Future<InterstitialAttemptResult> tryShowInterstitialAfterRun({
    required int completedRuns,
    required bool rewardedCompletedInRun,
    required AdsConfig config,
  }) async {
    return const InterstitialAttemptResult.skipped(InterstitialSkipReason.notDueByPacing);
  }
}

class _StubHaptics implements HapticsService {
  @override
  Future<void> onTraySelect() async {}

  @override
  Future<void> onUiTap() async {}

  @override
  Future<void> onClear({required bool isCombo}) async {}

  @override
  Future<void> onGameOver() async {}

  @override
  Future<void> onInvalidPlacement() async {}

  @override
  Future<void> onPlacement() async {}
}
