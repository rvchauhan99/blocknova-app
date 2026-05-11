import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../game_runtime/ad_guardrails.dart';
import 'ads_config.dart';
import 'ads_service.dart';

class AdMobAdsService implements AdsService {
  AdMobAdsService({
    String? rewardedUnitId,
    String? interstitialUnitId,
  })  : _rewardedUnitId = rewardedUnitId ?? _defaultRewardedUnitId(),
        _interstitialUnitId = interstitialUnitId ?? _defaultInterstitialUnitId();

  final String _rewardedUnitId;
  final String _interstitialUnitId;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _rewardedLoading = false;
  bool _interstitialLoading = false;

  @override
  Future<void> prepareRewarded() async {
    if (_rewardedAd != null || _rewardedLoading || _rewardedUnitId.isEmpty) {
      return;
    }
    _rewardedLoading = true;
    final completer = Completer<void>();
    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          _rewardedAd = ad;
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          debugPrint('Rewarded failed to load: $error');
          completer.complete();
        },
      ),
    );
    await completer.future;
  }

  @override
  Future<RewardedShowResult> showRewardedContinue({void Function()? onRewardedAdImpression}) async {
    if (_rewardedAd == null) {
      await prepareRewarded();
      if (_rewardedAd == null) {
        return const RewardedShowResult.failed(RewardedFailureCode.notLoaded);
      }
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;

    final completer = Completer<RewardedShowResult>();
    var rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        onRewardedAdImpression?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(
            rewardEarned
                ? const RewardedShowResult.completed()
                : const RewardedShowResult.failed(RewardedFailureCode.dismissed),
          );
        }
        unawaited(prepareRewarded());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(const RewardedShowResult.failed(RewardedFailureCode.error));
        }
        debugPrint('Rewarded failed to show: $error');
        unawaited(prepareRewarded());
      },
    );

    ad.show(
      onUserEarnedReward: (_, reward) {
        if (reward.amount >= 0) {
          // Reward object is intentionally read to avoid accidental callback drift.
        }
        rewardEarned = true;
      },
    );

    return completer.future;
  }

  @override
  Future<void> prepareInterstitial() async {
    if (_interstitialAd != null || _interstitialLoading || _interstitialUnitId.isEmpty) {
      return;
    }
    _interstitialLoading = true;
    final completer = Completer<void>();
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          _interstitialAd = ad;
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          debugPrint('Interstitial failed to load: $error');
          completer.complete();
        },
      ),
    );
    await completer.future;
  }

  @override
  Future<InterstitialAttemptResult> tryShowInterstitialAfterRun({
    required int completedRuns,
    required bool rewardedCompletedInRun,
    required AdsConfig config,
  }) async {
    final skip = AdGuardrails.interstitialSkipReason(
      completedRuns: completedRuns,
      rewardedCompletedInRun: rewardedCompletedInRun,
      config: config,
    );
    if (skip != null) {
      return InterstitialAttemptResult.skipped(skip);
    }

    if (_interstitialAd == null) {
      await prepareInterstitial();
      if (_interstitialAd == null) {
        return const InterstitialAttemptResult.skipped(InterstitialSkipReason.notLoaded);
      }
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;

    final completer = Completer<InterstitialAttemptResult>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(const InterstitialAttemptResult.shown());
        }
        unawaited(prepareInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        debugPrint('Interstitial failed to show: $error');
        if (!completer.isCompleted) {
          completer.complete(const InterstitialAttemptResult.skipped(InterstitialSkipReason.error));
        }
        unawaited(prepareInterstitial());
      },
    );
    ad.show();
    return completer.future;
  }
}

String _defaultRewardedUnitId() {
  const provided = String.fromEnvironment('ADMOB_REWARDED_UNIT_ID');
  if (provided.isNotEmpty) {
    return provided;
  }
  if (kDebugMode) {
    return 'ca-app-pub-3940256099942544/5224354917';
  }
  return '';
}

String _defaultInterstitialUnitId() {
  const provided = String.fromEnvironment('ADMOB_INTERSTITIAL_UNIT_ID');
  if (provided.isNotEmpty) {
    return provided;
  }
  if (kDebugMode) {
    return 'ca-app-pub-3940256099942544/1033173712';
  }
  return '';
}
