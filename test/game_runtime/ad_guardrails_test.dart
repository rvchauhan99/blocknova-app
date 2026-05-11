import 'package:blocknova_app/game_runtime/ad_guardrails.dart';
import 'package:blocknova_app/platform_services/ads/ads_config.dart';
import 'package:blocknova_app/platform_services/ads/ads_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rewarded continue allowed only at game-over and once per run', () {
    final allowed = AdGuardrails.canUseRewardedContinue(
      isGameOver: true,
      continueUsedInCurrentRun: false,
    );
    final deniedAfterUse = AdGuardrails.canUseRewardedContinue(
      isGameOver: true,
      continueUsedInCurrentRun: true,
    );
    final deniedWhenActive = AdGuardrails.canUseRewardedContinue(
      isGameOver: false,
      continueUsedInCurrentRun: false,
    );

    expect(allowed, isTrue);
    expect(deniedAfterUse, isFalse);
    expect(deniedWhenActive, isFalse);
  });

  test('Suppress interstitial during early onboarding runs', () {
    const config = AdsConfig(
      interstitialEveryCompletedRuns: 3,
      suppressInterstitialFirstRuns: 2,
    );

    final reason = AdGuardrails.interstitialSkipReason(
      completedRuns: 2,
      rewardedCompletedInRun: false,
      config: config,
    );

    expect(reason, InterstitialSkipReason.onboardingSuppression);
  });

  test('Suppress interstitial immediately after rewarded completion', () {
    const config = AdsConfig(
      interstitialEveryCompletedRuns: 3,
      suppressInterstitialFirstRuns: 0,
    );

    final reason = AdGuardrails.interstitialSkipReason(
      completedRuns: 3,
      rewardedCompletedInRun: true,
      config: config,
    );

    expect(reason, InterstitialSkipReason.afterRewardedCompletion);
  });

  test('Skip when not due by pacing and allow when due', () {
    const config = AdsConfig(
      interstitialEveryCompletedRuns: 3,
      suppressInterstitialFirstRuns: 0,
    );

    final skipReason = AdGuardrails.interstitialSkipReason(
      completedRuns: 4,
      rewardedCompletedInRun: false,
      config: config,
    );
    final allowedReason = AdGuardrails.interstitialSkipReason(
      completedRuns: 6,
      rewardedCompletedInRun: false,
      config: config,
    );

    expect(skipReason, InterstitialSkipReason.notDueByPacing);
    expect(allowedReason, isNull);
  });
}
