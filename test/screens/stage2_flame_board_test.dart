import 'package:blocknova_app/platform_services/ads/ads_config.dart';
import 'package:blocknova_app/platform_services/ads/ads_service.dart';
import 'package:blocknova_app/platform_services/analytics/analytics_service.dart';
import 'package:blocknova_app/platform_services/audio_service.dart';
import 'package:blocknova_app/platform_services/haptics_service.dart';
import 'package:blocknova_app/game_runtime/flame/stage2_flame_game.dart';
import 'package:blocknova_app/screens/game_placeholder_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flame board host path fires block_place on simulated cell tap', (WidgetTester tester) async {
    final analytics = _RecordingAnalyticsService();
    await tester.pumpWidget(
      MaterialApp(
        home: Stage2BoardScreen(
          analyticsService: analytics,
          adsService: _StubAds(),
          hapticsService: _StubHaptics(),
          audioService: StubAudioService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final gameFinder = find.byType(GameWidget<Stage2FlameGame>);
    expect(gameFinder, findsOneWidget);
    final game = tester.widget<GameWidget<Stage2FlameGame>>(gameFinder).game!;
    await game.testingSimulateCellTap(0, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(analytics.eventNames, contains('block_place'));

    await tester.pump(const Duration(milliseconds: 300));
  });
}

class _RecordingAnalyticsService implements AnalyticsService {
  final List<String> eventNames = <String>[];

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) {
    eventNames.add(name);
    return SynchronousFuture<void>(null);
  }
}

class _StubHaptics implements HapticsService {
  @override
  Future<void> onTraySelect() => Future<void>.value();

  @override
  Future<void> onUiTap() => Future<void>.value();

  @override
  Future<void> onClear({required bool isCombo}) => Future<void>.value();

  @override
  Future<void> onGameOver() => Future<void>.value();

  @override
  Future<void> onInvalidPlacement() => Future<void>.value();

  @override
  Future<void> onPlacement() => Future<void>.value();
}

class _StubAds implements AdsService {
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
