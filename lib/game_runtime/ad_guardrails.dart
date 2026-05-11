import '../platform_services/ads/ads_config.dart';
import '../platform_services/ads/ads_service.dart';

class AdGuardrails {
  const AdGuardrails._();

  static bool canUseRewardedContinue({
    required bool isGameOver,
    required bool continueUsedInCurrentRun,
  }) {
    return isGameOver && !continueUsedInCurrentRun;
  }

  static InterstitialSkipReason? interstitialSkipReason({
    required int completedRuns,
    required bool rewardedCompletedInRun,
    required AdsConfig config,
  }) {
    if (completedRuns <= config.suppressInterstitialFirstRuns) {
      return InterstitialSkipReason.onboardingSuppression;
    }
    if (rewardedCompletedInRun) {
      return InterstitialSkipReason.afterRewardedCompletion;
    }
    if (completedRuns % config.interstitialEveryCompletedRuns != 0) {
      return InterstitialSkipReason.notDueByPacing;
    }
    return null;
  }
}
