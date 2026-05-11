import 'ads_config.dart';

enum RewardedFailureCode {
  notLoaded,
  dismissed,
  noFill,
  error,
}

enum RewardedShowStatus {
  completed,
  failed,
}

class RewardedShowResult {
  const RewardedShowResult._({
    required this.status,
    this.failureCode,
  });

  const RewardedShowResult.completed()
      : this._(
          status: RewardedShowStatus.completed,
        );

  const RewardedShowResult.failed(RewardedFailureCode code)
      : this._(
          status: RewardedShowStatus.failed,
          failureCode: code,
        );

  final RewardedShowStatus status;
  final RewardedFailureCode? failureCode;
}

enum InterstitialSkipReason {
  notDueByPacing,
  onboardingSuppression,
  afterRewardedCompletion,
  notLoaded,
  error,
}

class InterstitialAttemptResult {
  const InterstitialAttemptResult._({
    required this.shown,
    this.skipReason,
  });

  const InterstitialAttemptResult.shown()
      : this._(
          shown: true,
        );

  const InterstitialAttemptResult.skipped(InterstitialSkipReason reason)
      : this._(
          shown: false,
          skipReason: reason,
        );

  final bool shown;
  final InterstitialSkipReason? skipReason;
}

abstract class AdsService {
  Future<void> prepareRewarded();

  Future<RewardedShowResult> showRewardedContinue({void Function()? onRewardedAdImpression});

  Future<void> prepareInterstitial();

  Future<InterstitialAttemptResult> tryShowInterstitialAfterRun({
    required int completedRuns,
    required bool rewardedCompletedInRun,
    required AdsConfig config,
  });
}
