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

void main() {
  testWidgets('Rewarded continue success resumes playable run', (tester) async {
    final fakeAds = _FakeAdsService(
      rewardedResult: const RewardedShowResult.completed(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stage2BoardScreen(
          initialSession: _gameOverSession(),
          adsService: fakeAds,
          analyticsService: _FakeAnalyticsService(),
          audioService: StubAudioService(),
          hapticsService: _StubHaptics(),
        ),
      ),
    );

    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    expect(find.textContaining('Continue granted'), findsOneWidget);
    expect(find.text('No valid moves remain.'), findsNothing);
  });

  testWidgets('Rewarded continue failure shows graceful fallback message', (tester) async {
    final fakeAds = _FakeAdsService(
      rewardedResult: const RewardedShowResult.failed(RewardedFailureCode.notLoaded),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stage2BoardScreen(
          initialSession: _gameOverSession(),
          adsService: fakeAds,
          analyticsService: _FakeAnalyticsService(),
          audioService: StubAudioService(),
          hapticsService: _StubHaptics(),
        ),
      ),
    );

    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    expect(find.textContaining('Continue unavailable'), findsOneWidget);
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

class _FakeAdsService implements AdsService {
  _FakeAdsService({
    required this.rewardedResult,
  });

  final RewardedShowResult rewardedResult;

  @override
  Future<void> prepareInterstitial() async {}

  @override
  Future<void> prepareRewarded() async {}

  @override
  Future<RewardedShowResult> showRewardedContinue({void Function()? onRewardedAdImpression}) async {
    onRewardedAdImpression?.call();
    return rewardedResult;
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

class _FakeAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {}
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
