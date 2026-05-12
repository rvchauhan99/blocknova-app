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
import 'package:blocknova_app/game_runtime/flame/stage2_flame_game.dart';
import 'package:blocknova_app/screens/game_placeholder_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flame board host path fires block_place on simulated cell tap', (
    WidgetTester tester,
  ) async {
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

    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'dragging a tray block shows a valid preview and places on drop',
    (WidgetTester tester) async {
      final analytics = _RecordingAnalyticsService();
      await _pumpStage2Board(tester, analytics);

      final gameFinder = find.byType(GameWidget<Stage2FlameGame>);
      final game = tester.widget<GameWidget<Stage2FlameGame>>(gameFinder).game!;
      final dragFinder = find.byType(Draggable<int>).first;

      final gesture = await tester.startGesture(tester.getCenter(dragFinder));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(gameFinder));
      await tester.pump();

      expect(game.testingHasPreview, isTrue);
      expect(game.testingPreviewIsValid, isTrue);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(game.testingHasPreview, isFalse);
      expect(
        analytics.eventNames.where((e) => e == 'block_place'),
        hasLength(1),
      );
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('dropping outside the board clears preview without placing', (
    WidgetTester tester,
  ) async {
    final analytics = _RecordingAnalyticsService();
    await _pumpStage2Board(tester, analytics);

    final gameFinder = find.byType(GameWidget<Stage2FlameGame>);
    final game = tester.widget<GameWidget<Stage2FlameGame>>(gameFinder).game!;
    final dragFinder = find.byType(Draggable<int>).first;

    final gesture = await tester.startGesture(tester.getCenter(dragFinder));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(gameFinder));
    await tester.pump();
    expect(game.testingHasPreview, isTrue);

    await gesture.moveTo(const Offset(18, 18));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(game.testingHasPreview, isFalse);
    expect(analytics.eventNames.where((e) => e == 'block_place'), isEmpty);
  });

  testWidgets('edge drag clamps large preview fully inside board', (
    WidgetTester tester,
  ) async {
    final analytics = _RecordingAnalyticsService();
    await _pumpStage2Board(
      tester,
      analytics,
      initialSession: _edgeClampSession(),
    );

    final gameFinder = find.byType(GameWidget<Stage2FlameGame>);
    final game = tester.widget<GameWidget<Stage2FlameGame>>(gameFinder).game!;
    final dragFinder = find.byType(Draggable<int>).first;
    final boardRect = tester.getRect(gameFinder);

    final gesture = await tester.startGesture(tester.getCenter(dragFinder));
    await tester.pump();
    await gesture.moveTo(boardRect.topLeft + const Offset(1, 1));
    await tester.pump();

    expect(game.testingHasPreview, isTrue);
    expect(game.testingPreviewX, 0);
    expect(game.testingPreviewY, 0);

    await gesture.moveTo(boardRect.bottomRight - const Offset(1, 1));
    await tester.pump();

    expect(game.testingHasPreview, isTrue);
    expect(game.testingPreviewX, 5);
    expect(game.testingPreviewY, 5);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('pointer inside board hides floating drag feedback at edge', (
    WidgetTester tester,
  ) async {
    final analytics = _RecordingAnalyticsService();
    await _pumpStage2Board(
      tester,
      analytics,
      initialSession: _edgeClampSession(),
    );

    final gameFinder = find.byType(GameWidget<Stage2FlameGame>);
    final game = tester.widget<GameWidget<Stage2FlameGame>>(gameFinder).game!;
    final dragFinder = find.byType(Draggable<int>).first;
    final boardRect = tester.getRect(gameFinder);

    final gesture = await tester.startGesture(tester.getCenter(dragFinder));
    await tester.pump();
    await gesture.moveTo(boardRect.topLeft + const Offset(1, 1));
    await tester.pump();

    expect(game.testingHasPreview, isTrue);
    expect(game.testingPreviewX, 0);
    expect(game.testingPreviewY, 0);

    final feedbackOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey<String>('block-tray-drag-feedback-0')).last,
    );
    expect(feedbackOpacity.opacity, 0.0);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('edge drop places at the clamped preview origin', (
    WidgetTester tester,
  ) async {
    final analytics = _RecordingAnalyticsService();
    await _pumpStage2Board(
      tester,
      analytics,
      initialSession: _edgeClampSession(),
    );

    final gameFinder = find.byType(GameWidget<Stage2FlameGame>);
    final game = tester.widget<GameWidget<Stage2FlameGame>>(gameFinder).game!;
    final dragFinder = find.byType(Draggable<int>).first;
    final boardRect = tester.getRect(gameFinder);

    final gesture = await tester.startGesture(tester.getCenter(dragFinder));
    await tester.pump();
    await gesture.moveTo(boardRect.topLeft + const Offset(1, 1));
    await tester.pump();
    expect(game.testingPreviewX, 0);
    expect(game.testingPreviewY, 0);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(game.visualSession.board.colorAt(0, 0), isNotNull);
    expect(game.visualSession.board.colorAt(2, 2), isNotNull);
    expect(analytics.eventNames.where((e) => e == 'block_place'), hasLength(1));

    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'game-over screen shows final panel without block placement log',
    (WidgetTester tester) async {
      final analytics = _RecordingAnalyticsService();
      await tester.pumpWidget(
        MaterialApp(
          home: Stage2BoardScreen(
            initialSession: _gameOverSession(),
            analyticsService: analytics,
            adsService: _StubAds(),
            hapticsService: _StubHaptics(),
            audioService: StubAudioService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('No valid moves remain.'), findsOneWidget);
      expect(analytics.eventNames.where((e) => e == 'block_place'), isEmpty);
      expect(
        analytics.eventNames.where((e) => e == 'continue_offer_shown'),
        hasLength(1),
      );
    },
  );

  testWidgets('rewarded completion grants one continue from game over', (
    WidgetTester tester,
  ) async {
    final analytics = _RecordingAnalyticsService();
    final ads = _StubAds(rewardedResult: const RewardedShowResult.completed());

    await _pumpGameOverBoard(tester, analytics: analytics, ads: ads);
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(ads.rewardedShowCalls, 1);
    expect(ads.rewardedImpressionCallbacks, 1);
    expect(find.text('GAME OVER'), findsNothing);
    expect(analytics.eventNames, contains('rewarded_impression'));
    expect(analytics.eventNames, contains('rewarded_complete'));
    expect(analytics.eventNames, contains('continue_granted'));
    expect(analytics.eventNames.where((e) => e == 'rewarded_failed'), isEmpty);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('rewarded failure keeps game over and does not grant continue', (
    WidgetTester tester,
  ) async {
    final analytics = _RecordingAnalyticsService();
    final ads = _StubAds(
      rewardedResult: const RewardedShowResult.failed(
        RewardedFailureCode.dismissed,
      ),
    );

    await _pumpGameOverBoard(tester, analytics: analytics, ads: ads);
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(ads.rewardedShowCalls, 1);
    expect(find.text('GAME OVER'), findsOneWidget);
    expect(analytics.eventNames, contains('rewarded_failed'));
    expect(analytics.eventNames.where((e) => e == 'continue_granted'), isEmpty);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('second continue in the same run is blocked before ad show', (
    WidgetTester tester,
  ) async {
    final analytics = _RecordingAnalyticsService();
    final ads = _StubAds(rewardedResult: const RewardedShowResult.completed());

    await _pumpGameOverBoard(
      tester,
      analytics: analytics,
      ads: ads,
      initialContinueUsedInCurrentRun: true,
    );
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(ads.rewardedShowCalls, 0);
    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('LOADING...'), findsNothing);
    expect(analytics.eventNames.where((e) => e == 'continue_granted'), isEmpty);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('end run starts a fresh run and clears game over panel', (
    WidgetTester tester,
  ) async {
    final analytics = _RecordingAnalyticsService();
    final ads = _StubAds();

    await _pumpGameOverBoard(
      tester,
      analytics: analytics,
      ads: ads,
      initialContinueUsedInCurrentRun: true,
    );
    await tester.tap(find.text('END RUN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('GAME OVER'), findsNothing);
    expect(ads.interstitialCalls, 1);
    expect(analytics.eventNames, contains('interstitial_skipped'));

    await tester.pump(const Duration(seconds: 1));
  });
}

Future<void> _pumpStage2Board(
  WidgetTester tester,
  _RecordingAnalyticsService analytics, {
  GameSession? initialSession,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Stage2BoardScreen(
        initialSession: initialSession,
        analyticsService: analytics,
        adsService: _StubAds(),
        hapticsService: _StubHaptics(),
        audioService: StubAudioService(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

GameSession _edgeClampSession() {
  return const GameSession(
    board: BoardState(size: 8),
    queue: BlockQueue([
      BlockShape(
        colorType: BlockColorType.yellow,
        id: 'square_3x3',
        cells: [
          GridPoint(0, 0),
          GridPoint(1, 0),
          GridPoint(2, 0),
          GridPoint(0, 1),
          GridPoint(1, 1),
          GridPoint(2, 1),
          GridPoint(0, 2),
          GridPoint(1, 2),
          GridPoint(2, 2),
        ],
      ),
    ]),
  );
}

Future<void> _pumpGameOverBoard(
  WidgetTester tester, {
  required _RecordingAnalyticsService analytics,
  required _StubAds ads,
  bool initialContinueUsedInCurrentRun = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Stage2BoardScreen(
        initialSession: _gameOverSession(),
        initialContinueUsedInCurrentRun: initialContinueUsedInCurrentRun,
        analyticsService: analytics,
        adsService: ads,
        hapticsService: _StubHaptics(),
        audioService: StubAudioService(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

GameSession _gameOverSession() {
  final occupied = <int, BlockColorType>{};
  const size = 8;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if ((x + y).isEven) {
        occupied[y * size + x] = BlockColorType.purple;
      }
    }
  }

  return GameSession(
    board: BoardState(size: size, cellColors: occupied),
    queue: const BlockQueue([
      BlockShape(
        colorType: BlockColorType.yellow,
        id: 'square_3x3',
        cells: [
          GridPoint(0, 0),
          GridPoint(1, 0),
          GridPoint(2, 0),
          GridPoint(0, 1),
          GridPoint(1, 1),
          GridPoint(2, 1),
          GridPoint(0, 2),
          GridPoint(1, 2),
          GridPoint(2, 2),
        ],
      ),
    ]),
    isGameOver: true,
  );
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
  _StubAds({
    this.rewardedResult = const RewardedShowResult.failed(
      RewardedFailureCode.notLoaded,
    ),
  });

  final RewardedShowResult rewardedResult;
  int rewardedShowCalls = 0;
  int rewardedImpressionCallbacks = 0;
  int interstitialCalls = 0;

  @override
  Future<void> prepareInterstitial() async {}

  @override
  Future<void> prepareRewarded() async {}

  @override
  Future<RewardedShowResult> showRewardedContinue({
    void Function()? onRewardedAdImpression,
  }) async {
    rewardedShowCalls += 1;
    if (rewardedResult.status == RewardedShowStatus.completed) {
      rewardedImpressionCallbacks += 1;
      onRewardedAdImpression?.call();
    }
    return rewardedResult;
  }

  @override
  Future<InterstitialAttemptResult> tryShowInterstitialAfterRun({
    required int completedRuns,
    required bool rewardedCompletedInRun,
    required AdsConfig config,
  }) async {
    interstitialCalls += 1;
    return const InterstitialAttemptResult.skipped(
      InterstitialSkipReason.notDueByPacing,
    );
  }
}
