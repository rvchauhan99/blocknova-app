class AdsConfig {
  const AdsConfig({
    required this.interstitialEveryCompletedRuns,
    required this.suppressInterstitialFirstRuns,
  });

  factory AdsConfig.defaults() {
    return const AdsConfig(
      interstitialEveryCompletedRuns: 3,
      suppressInterstitialFirstRuns: 2,
    );
  }

  factory AdsConfig.fromRuntime({
    required Map<String, Object?> values,
    AdsConfig? fallback,
  }) {
    final base = fallback ?? AdsConfig.defaults();
    final every = values['interstitialEveryCompletedRuns'];
    final suppress = values['suppressInterstitialFirstRuns'];

    final parsedEvery = every is int ? every : int.tryParse('$every');
    final parsedSuppress = suppress is int ? suppress : int.tryParse('$suppress');

    return AdsConfig(
      interstitialEveryCompletedRuns:
          (parsedEvery == null || parsedEvery <= 0) ? base.interstitialEveryCompletedRuns : parsedEvery,
      suppressInterstitialFirstRuns:
          (parsedSuppress == null || parsedSuppress < 0) ? base.suppressInterstitialFirstRuns : parsedSuppress,
    );
  }

  final int interstitialEveryCompletedRuns;
  final int suppressInterstitialFirstRuns;
}
