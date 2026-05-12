import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../bootstrap/auth_bootstrap.dart';
import '../game_core/block_shape.dart';
import '../game_core/game_session.dart';
import '../game_core/grid_point.dart';
import '../game_runtime/ad_guardrails.dart';
import '../game_runtime/flame/stage2_flame_game.dart';
import '../game_runtime/runtime_feedback.dart'
    show RuntimeEventType, RuntimeFeedbackEvent;
import '../game_runtime/runtime_session_driver.dart';
import '../platform_services/ads/admob_ads_service.dart';
import '../platform_services/ads/ads_service.dart';
import '../platform_services/remote_config/blocknova_remote_config.dart';
import '../platform_services/analytics/analytics_scope.dart';
import '../platform_services/analytics/analytics_service.dart';
import '../platform_services/asset_audio_service.dart';
import '../platform_services/audio_service.dart';
import '../platform_services/backend/blocknova_backend_service.dart';
import '../platform_services/haptics_service.dart';
import '../platform_services/personal_best_store.dart';
import '../theme/arcade_shell_theme.dart';
import '../theme/blastnova_brand.dart';
import '../widgets/arcade_ambient_background.dart';

// Removed kArcadeBlockColors in favor of Stage2FlameGame.blockColors

class GamePlaceholderScreen extends StatelessWidget {
  const GamePlaceholderScreen({
    super.key,
    this.analyticsService,
    this.backendService,
    this.audioService,
    this.hapticsService,
  });

  final AnalyticsService? analyticsService;
  final BlocknovaBackendService? backendService;
  final AudioService? audioService;
  final HapticsService? hapticsService;

  @override
  Widget build(BuildContext context) {
    return Stage2BoardScreen(
      analyticsService: analyticsService ?? AnalyticsScope.maybeOf(context),
      backendService: backendService,
      audioService: audioService,
      hapticsService: hapticsService,
    );
  }
}

class Stage2BoardScreen extends StatefulWidget {
  const Stage2BoardScreen({
    super.key,
    this.initialSession,
    this.adsService,
    this.analyticsService,
    this.backendService,
    this.hapticsService,
    this.audioService,
    this.initialContinueUsedInCurrentRun = false,
  });

  final GameSession? initialSession;
  final AdsService? adsService;
  final AnalyticsService? analyticsService;
  final BlocknovaBackendService? backendService;

  /// When null, uses [SystemHapticsService] (tests may inject a no-op stub).
  final HapticsService? hapticsService;

  /// When null, uses [AssetAudioService] (tests should inject [StubAudioService]).
  final AudioService? audioService;

  /// Test hook for restoring a run that already consumed its rewarded continue.
  final bool initialContinueUsedInCurrentRun;

  @override
  State<Stage2BoardScreen> createState() => _Stage2BoardScreenState();
}

class _Stage2BoardScreenState extends State<Stage2BoardScreen>
    with TickerProviderStateMixin {
  static const String _runMode = 'sandbox';

  late GameSession _session;
  late final RuntimeSessionDriver _runtimeDriver;
  late final AdsService _adsService;
  late final AnalyticsService _analytics;
  late final BlocknovaBackendService _backend;
  String? _comboMessage;
  Set<int> _placedFlashKeys = <int>{};
  Set<int> _clearedFlashKeys = <int>{};
  int? _invalidTapKey;
  int _completedRuns = 0;
  int _placementMoves = 0;
  DateTime? _runStartedAt;
  bool _continueUsedInCurrentRun = false;
  bool _rewardedCompletedInCurrentRun = false;
  bool _continueLoading = false;
  bool _continueOfferLoggedForGameOver = false;
  bool _runRecorded = false;

  late final Stage2FlameGame _flameGame;
  late final AudioService _audio;
  late final HapticsService _haptics;
  late AnimationController _comboPopController;
  late AnimationController _shakeController;
  late Animation<double> _shakeTween;
  late AnimationController _scoreBumpController;
  late Animation<double> _scoreBumpAnim;
  late AnimationController _boardPulseController;
  final List<_FlyoutItem> _flyouts = <_FlyoutItem>[];
  final List<Timer> _flyoutTimers = <Timer>[];
  int? _draggingQueueIndex;
  Offset? _dragPointerGlobalPosition;
  Offset _dragFeedbackAnchorOffset = Offset.zero;
  final ValueNotifier<bool> _dragIsOverBoard = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession ?? GameSession.stage2Start();
    _continueUsedInCurrentRun = widget.initialContinueUsedInCurrentRun;
    _haptics = widget.hapticsService ?? SystemHapticsService();
    _audio = widget.audioService ?? AssetAudioService();
    _runtimeDriver = RuntimeSessionDriver(
      hapticsService: _haptics,
      audioService: _audio,
    );
    _adsService = widget.adsService ?? AdMobAdsService();
    _analytics = widget.analyticsService ?? DebugAnalyticsService();
    _backend = widget.backendService ?? BlocknovaBackendService();
    _flameGame = Stage2FlameGame(onCellTap: _tapCell, initialSession: _session);
    _comboPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _shakeTween = TweenSequence<double>(
      <TweenSequenceItem<double>>[
        TweenSequenceItem(tween: Tween(begin: 0, end: -14), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -14, end: 14), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 14, end: -10), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -10, end: 6), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 6, end: -2), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -2, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
    _scoreBumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scoreBumpAnim =
        TweenSequence<double>(<TweenSequenceItem<double>>[
          TweenSequenceItem(
            tween: Tween<double>(begin: 1, end: 1.12),
            weight: 28,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.12, end: 1),
            weight: 72,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _scoreBumpController,
            curve: Curves.easeOutCubic,
          ),
        );
    _boardPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    unawaited(ensureAnonymousAuth());
    _beginRunAnalytics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        _analytics.logEvent(
          'screen_view',
          parameters: <String, Object?>{'screen_name': 'game'},
        ),
      );
    });
    _warmupAds();
    if (_session.isGameOver) {
      _continueOfferLoggedForGameOver = true;
      unawaited(_analytics.logEvent('continue_offer_shown'));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncFlameBoard();
    });
  }

  @override
  void dispose() {
    _recordRunOutcome(endReason: 'abandoned');
    for (final t in _flyoutTimers) {
      t.cancel();
    }
    _flyoutTimers.clear();
    _comboPopController.dispose();
    _shakeController.dispose();
    _scoreBumpController.dispose();
    _boardPulseController.dispose();
    _dragIsOverBoard.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  void _pushFlyout(String text, Color color) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_flyouts.length}';
    if (!mounted) {
      return;
    }
    setState(() => _flyouts.add(_FlyoutItem(id: id, text: text, color: color)));
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 900), () {
      _flyoutTimers.remove(timer);
      if (!mounted) {
        return;
      }
      setState(() => _flyouts.removeWhere((e) => e.id == id));
    });
    _flyoutTimers.add(timer);
  }

  void _syncFlameBoard() {
    _flameGame.applySnapshot(
      session: _session,
      placedFlashKeys: _placedFlashKeys,
      clearedFlashKeys: _clearedFlashKeys,
      invalidTapKey: _invalidTapKey,
    );
  }

  void _beginRunAnalytics() {
    _placementMoves = 0;
    _runRecorded = false;
    _runStartedAt = DateTime.now();
    unawaited(
      _analytics.logEvent(
        'run_start',
        parameters: <String, Object?>{'mode': _runMode},
      ),
    );
  }

  void _recordRunOutcome({required String endReason}) {
    if (_runRecorded) {
      return;
    }
    _runRecorded = true;

    if (endReason == 'abandoned' &&
        _placementMoves == 0 &&
        _session.score == 0) {
      return;
    }

    final anchor = _runStartedAt;
    final durationSec = anchor == null
        ? 0
        : DateTime.now().difference(anchor).inSeconds;

    unawaited(PersonalBestStore.recordIfBetter(_session.score));

    unawaited(
      _analytics.logEvent(
        'run_end',
        parameters: <String, Object?>{
          'mode': _runMode,
          'score': _session.score,
          'duration_sec': durationSec,
          'moves': _placementMoves,
          'end_reason': endReason,
        },
      ),
    );

    unawaited(
      _trySubmitEndlessLeaderboard(
        score: _session.score,
        durationSec: durationSec,
        moves: _placementMoves,
      ),
    );
  }

  Future<void> _warmupAds() async {
    await _adsService.prepareRewarded();
    await _adsService.prepareInterstitial();
  }

  Future<void> _tapCell(int x, int y) async {
    final beforeSession = _session;
    final runtimeResult = await _runtimeDriver.handlePlacementTap(
      current: _session,
      x: x,
      y: y,
    );
    RuntimeFeedbackEvent? comboEvent;
    RuntimeFeedbackEvent? lineClearEvent;
    RuntimeFeedbackEvent? rejectionEvent;
    for (final event in runtimeResult.events) {
      if (event.type == RuntimeEventType.combo) {
        comboEvent = event;
      } else if (event.type == RuntimeEventType.lineClear) {
        lineClearEvent = event;
      } else if (event.type == RuntimeEventType.placementRejected) {
        rejectionEvent = event;
      }
    }

    final accepted = runtimeResult.events.any(
      (e) => e.type == RuntimeEventType.placementAccepted,
    );

    final newInvalid = rejectionEvent?.invalidTapKey;

    setState(() {
      _session = runtimeResult.session;
      _comboMessage = comboEvent?.message;
      _placedFlashKeys = runtimeResult.events.fold<Set<int>>(
        <int>{},
        (acc, event) => {...acc, ...event.placedKeys},
      );
      _clearedFlashKeys = runtimeResult.events.fold<Set<int>>(
        <int>{},
        (acc, event) => {...acc, ...event.clearedKeys},
      );
      _invalidTapKey = newInvalid;
      if (accepted) {
        _placementMoves += 1;
      }
      if (!_session.isGameOver) {
        _continueOfferLoggedForGameOver = false;
      }
    });
    _syncFlameBoard();

    if (rejectionEvent != null) {
      _shakeController.forward(from: 0);
      _pushFlyout('INVALID', const Color(0xFFFF3B30));
    }

    if (comboEvent != null) {
      _comboPopController.forward(from: 0);
    }

    if (accepted && _session.score > beforeSession.score) {
      _scoreBumpController.forward(from: 0);
      _boardPulseController.forward(from: 0);
      if (_session.lastMoveScore > 0) {
        _pushFlyout('+${_session.lastMoveScore}', const Color(0xFFFFEA00));
      }
      if (lineClearEvent != null && _session.lastMoveClears >= 3) {
        _pushFlyout('PERFECT', const Color(0xFF69F0AE));
      }
      if (comboEvent != null) {
        _pushFlyout('COMBO', const Color(0xFFE040FB));
      }
    }

    if (accepted) {
      final shape = beforeSession.selectedShape;
      if (shape != null) {
        unawaited(
          _analytics.logEvent(
            'block_place',
            parameters: <String, Object?>{
              'shape_id': shape.id,
              'tiles_count': shape.tileCount,
            },
          ),
        );
      }
    }
    if (lineClearEvent != null) {
      unawaited(
        _analytics.logEvent(
          'line_clear',
          parameters: <String, Object?>{
            'lines_cleared': lineClearEvent.clearedLines,
          },
        ),
      );
    }
    if (comboEvent != null) {
      unawaited(
        _analytics.logEvent(
          'combo_trigger',
          parameters: <String, Object?>{'combo_count': comboEvent.comboCount},
        ),
      );
    }

    if (lineClearEvent != null || _placedFlashKeys.isNotEmpty) {
      Future<void>.delayed(
        Duration(milliseconds: lineClearEvent != null ? 420 : 240),
        () {
          if (!mounted) {
            return;
          }
          setState(() {
            _placedFlashKeys = <int>{};
            _clearedFlashKeys = <int>{};
          });
          _syncFlameBoard();
        },
      );
    }

    if (_invalidTapKey != null) {
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _invalidTapKey = null;
        });
        _syncFlameBoard();
      });
    }

    if (_comboMessage != null) {
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _comboMessage = null;
        });
        _syncFlameBoard();
      });
    }

    if (_session.isGameOver && !_continueOfferLoggedForGameOver) {
      _continueOfferLoggedForGameOver = true;
      await _analytics.logEvent('continue_offer_shown');
    }
  }

  Future<void> _onContinueRewardedTap() async {
    if (_continueLoading) {
      return;
    }
    if (!AdGuardrails.canUseRewardedContinue(
      isGameOver: _session.isGameOver,
      continueUsedInCurrentRun: _continueUsedInCurrentRun,
    )) {
      if (_continueUsedInCurrentRun) {
        _pushFlyout('Only one continue per run.', const Color(0xFFFF3B30));
      } else {
        _pushFlyout(
          'Continue is only available at game over.',
          const Color(0xFFFF3B30),
        );
      }
      _syncFlameBoard();
      return;
    }

    setState(() {
      _continueLoading = true;
    });
    _pushFlyout('Loading rewarded ad...', const Color(0xFFFFFFFF));
    _syncFlameBoard();

    final result = await _adsService.showRewardedContinue(
      onRewardedAdImpression: () {
        unawaited(_analytics.logEvent('rewarded_impression'));
      },
    );
    if (!mounted) {
      return;
    }

    if (result.status == RewardedShowStatus.completed) {
      await _analytics.logEvent('rewarded_complete');
      await _analytics.logEvent('continue_granted');
      setState(() {
        _session = _resumePlayableSession(_session);
        _continueUsedInCurrentRun = true;
        _rewardedCompletedInCurrentRun = true;
        _continueLoading = false;
        _continueOfferLoggedForGameOver = false;
      });
      _pushFlyout('Continue granted. Keep playing!', const Color(0xFF69F0AE));
      _syncFlameBoard();
      return;
    }

    final code = result.failureCode?.name ?? RewardedFailureCode.error.name;
    await _analytics.logEvent(
      'rewarded_failed',
      parameters: <String, Object?>{'error_code': code},
    );
    setState(() {
      _continueLoading = false;
    });
    _pushFlyout(
      'Continue unavailable ($code). You can end run.',
      const Color(0xFFFF3B30),
    );
    _syncFlameBoard();
  }

  Future<void> _onEndRunTap() async {
    final endReason = _session.isGameOver ? 'no_moves' : 'user_end';
    _recordRunOutcome(endReason: endReason);

    final nextCompletedRuns = _completedRuns + 1;
    final interstitialResult = await _adsService.tryShowInterstitialAfterRun(
      completedRuns: nextCompletedRuns,
      rewardedCompletedInRun: _rewardedCompletedInCurrentRun,
      config: BlocknovaRemoteConfig.adsConfig,
    );

    if (interstitialResult.shown) {
      await _analytics.logEvent('interstitial_impression');
    } else {
      await _analytics.logEvent(
        'interstitial_skipped',
        parameters: <String, Object?>{
          'reason':
              interstitialResult.skipReason?.name ??
              InterstitialSkipReason.error.name,
        },
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _completedRuns = nextCompletedRuns;
      _session = GameSession.stage2Start();
      _continueUsedInCurrentRun = false;
      _rewardedCompletedInCurrentRun = false;
      _continueLoading = false;
      _continueOfferLoggedForGameOver = false;
    });
    _pushFlyout('Run ended. New run started.', const Color(0xFFFFFFFF));
    _syncFlameBoard();
    _beginRunAnalytics();
  }

  Future<void> _trySubmitEndlessLeaderboard({
    required int score,
    required int durationSec,
    required int moves,
  }) async {
    if (!Firebase.apps.isNotEmpty || !_backend.isAvailable) {
      await _analytics.logEvent(
        'leaderboard_submit_result',
        parameters: <String, Object?>{
          'accepted': false,
          'reject_reason': 'firebase_unavailable',
        },
      );
      return;
    }
    final authed = await ensureAnonymousAuth();
    if (!authed || FirebaseAuth.instance.currentUser == null) {
      if (kDebugMode) {
        debugPrint('Leaderboard submit skipped: anonymous auth unavailable.');
      }
      await _analytics.logEvent(
        'leaderboard_submit_result',
        parameters: <String, Object?>{
          'accepted': false,
          'reject_reason': 'not_signed_in',
        },
      );
      return;
    }
    final runId = const Uuid().v4();
    final movesForServer = moves < 1 && score > 0 ? 1 : moves;
    try {
      final r = await _backend.submitRun(
        runId: runId,
        mode: 'endless',
        score: score,
        durationSec: durationSec,
        moves: movesForServer,
      );
      if (kDebugMode && !r.accepted) {
        debugPrint('submitRun rejected: ${r.reason ?? "unknown"}');
      }
      await _analytics.logEvent(
        'leaderboard_submit_result',
        parameters: <String, Object?>{
          'accepted': r.accepted,
          'reject_reason': r.accepted ? '' : (r.reason ?? 'rejected'),
        },
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('submitRun client error: $e\n$st');
      }
      await _analytics.logEvent(
        'leaderboard_submit_result',
        parameters: <String, Object?>{
          'accepted': false,
          'reject_reason': 'client_error',
        },
      );
    }
  }

  GameSession _resumePlayableSession(GameSession source) {
    return source.withRecoveryQueue(math.Random());
  }

  void _showPauseSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF01A1F35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              BlastNovaBrand.kPauseTitle,
              style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                unawaited(_haptics.onUiTap());
                unawaited(_audio.onUiTap());
                Navigator.pop(ctx);
              },
              child: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }

  final GlobalKey _boardKey = GlobalKey();

  bool _isGlobalPointInsideBoard(Offset globalOffset) {
    final boardContext = _boardKey.currentContext;
    final renderObject = boardContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }

    final localOffset = renderObject.globalToLocal(globalOffset);
    final side = math.min(renderObject.size.width, renderObject.size.height);
    return side > 0 &&
        localOffset.dx >= 0 &&
        localOffset.dy >= 0 &&
        localOffset.dx <= side &&
        localOffset.dy <= side;
  }

  _BoardDropPreview? _previewForGlobalOffset({
    required int queueIndex,
    required Offset globalOffset,
  }) {
    if (queueIndex < 0 || queueIndex >= _session.queue.items.length) {
      return null;
    }
    final boardContext = _boardKey.currentContext;
    final renderObject = boardContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    final localOffset = renderObject.globalToLocal(globalOffset);
    final side = math.min(renderObject.size.width, renderObject.size.height);
    if (side <= 0 ||
        localOffset.dx < 0 ||
        localOffset.dy < 0 ||
        localOffset.dx > side ||
        localOffset.dy > side) {
      return null;
    }

    final shape = _session.queue.items[queueIndex];
    final center = _shapeCenterOffset(shape);
    final cell = side / _session.board.size;
    final rawOriginX = (localOffset.dx / cell).floor() - center.dx;
    final rawOriginY = (localOffset.dy / cell).floor() - center.dy;
    final bounds = _shapeBounds(shape);
    final minOriginX = -bounds.minX;
    final maxOriginX = _session.board.size - 1 - bounds.maxX;
    final minOriginY = -bounds.minY;
    final maxOriginY = _session.board.size - 1 - bounds.maxY;
    final originX = math.max(minOriginX, math.min(maxOriginX, rawOriginX));
    final originY = math.max(minOriginY, math.min(maxOriginY, rawOriginY));
    final isValid = _session.board.canPlace(
      shape: shape,
      originX: originX,
      originY: originY,
    );

    return _BoardDropPreview(
      queueIndex: queueIndex,
      shape: shape,
      originX: originX,
      originY: originY,
      isValid: isValid,
    );
  }

  GridPoint _shapeCenterOffset(BlockShape shape) {
    final bounds = _shapeBounds(shape);
    return GridPoint(
      ((bounds.minX + bounds.maxX) / 2).round(),
      ((bounds.minY + bounds.maxY) / 2).round(),
    );
  }

  _ShapeBounds _shapeBounds(BlockShape shape) {
    var minX = shape.cells.first.dx;
    var maxX = shape.cells.first.dx;
    var minY = shape.cells.first.dy;
    var maxY = shape.cells.first.dy;
    for (final c in shape.cells) {
      minX = math.min(minX, c.dx);
      maxX = math.max(maxX, c.dx);
      minY = math.min(minY, c.dy);
      maxY = math.max(maxY, c.dy);
    }
    return _ShapeBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  void _updateDragPreview(DragTargetDetails<int> details) {
    final preview = _previewForDragOffset(
      queueIndex: details.data,
      dragOffset: details.offset,
    );
    if (preview == null) {
      _setDragIsOverBoard(false);
      _flameGame.clearPreview();
      return;
    }
    _setDragIsOverBoard(true);
    _flameGame.setPreview(
      preview.shape,
      preview.originX,
      preview.originY,
      isValid: preview.isValid,
    );
  }

  void _setDragIsOverBoard(bool value) {
    if (_dragIsOverBoard.value == value) {
      return;
    }
    _dragIsOverBoard.value = value;
  }

  void _clearDragState() {
    if (!mounted) {
      return;
    }
    _setDragIsOverBoard(false);
    _dragPointerGlobalPosition = null;
    _dragFeedbackAnchorOffset = Offset.zero;
    setState(() {
      _draggingQueueIndex = null;
    });
    _flameGame.clearPreview();
  }

  Offset _pointerGlobalFromDragOffset(Offset dragOffset) {
    return dragOffset + _dragFeedbackAnchorOffset;
  }

  _BoardDropPreview? _previewForDragOffset({
    required int queueIndex,
    required Offset dragOffset,
  }) {
    return _previewForGlobalOffset(
          queueIndex: queueIndex,
          globalOffset: _pointerGlobalFromDragOffset(dragOffset),
        ) ??
        _previewForGlobalOffset(
          queueIndex: queueIndex,
          globalOffset: dragOffset,
        );
  }

  Offset _captureDragFeedbackAnchor(
    BuildContext context,
    Offset globalPosition,
  ) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      _dragFeedbackAnchorOffset = Offset.zero;
      return Offset.zero;
    }
    _dragFeedbackAnchorOffset = renderObject.globalToLocal(globalPosition);
    return _dragFeedbackAnchorOffset;
  }

  void _handleDragPointerUpdate(int queueIndex, Offset dragOffset) {
    final globalPosition = _pointerGlobalFromDragOffset(dragOffset);
    _dragPointerGlobalPosition = globalPosition;
    final preview = _previewForDragOffset(
      queueIndex: queueIndex,
      dragOffset: dragOffset,
    );
    if (preview == null) {
      return;
    }

    _setDragIsOverBoard(true);
    _flameGame.setPreview(
      preview.shape,
      preview.originX,
      preview.originY,
      isValid: preview.isValid,
    );
  }

  void _handleDragTargetLeave() {
    final globalPosition = _dragPointerGlobalPosition;
    if (globalPosition != null && _isGlobalPointInsideBoard(globalPosition)) {
      return;
    }
    _setDragIsOverBoard(false);
    _flameGame.clearPreview();
  }

  void _showInvalidDropFeedback() {
    unawaited(_haptics.onInvalidPlacement());
    unawaited(_audio.onInvalidPlacement());
    _shakeController.forward(from: 0);
    _pushFlyout('DROP ON BOARD', const Color(0xFFFF3B30));
  }

  Future<void> _acceptDraggedBlock(DragTargetDetails<int> details) async {
    final preview = _previewForDragOffset(
      queueIndex: details.data,
      dragOffset: details.offset,
    );
    _setDragIsOverBoard(false);
    _dragPointerGlobalPosition = null;
    _dragFeedbackAnchorOffset = Offset.zero;
    _flameGame.clearPreview();

    if (preview == null) {
      _clearDragState();
      _showInvalidDropFeedback();
      return;
    }

    setState(() {
      _draggingQueueIndex = null;
      _session = _session.selectQueueIndex(details.data);
    });
    await _tapCell(preview.originX, preview.originY);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: ArcadeShellTheme.bgNavy,
      body: ArcadeAmbientBackground(
        child: SafeArea(
          child: DragTarget<int>(
            onWillAcceptWithDetails: (_) => !_session.isGameOver,
            onMove: _updateDragPreview,
            onLeave: (_) => _handleDragTargetLeave(),
            onAcceptWithDetails: (details) {
              unawaited(_acceptDraggedBlock(details));
            },
            builder: (context, candidateData, rejectedData) => Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(
                            width: 48,
                          ), // Padding equivalent to IconButton
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  BlastNovaBrand.kBrandWordmark.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.orbitron(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildCompactHud(context),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Pause',
                            onPressed: () {
                              unawaited(_haptics.onUiTap());
                              unawaited(_audio.onUiTap());
                              _showPauseSheet();
                            },
                            icon: const Icon(
                              Icons.pause_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_comboMessage != null) _buildComboBanner(),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: Listenable.merge(<Listenable>[
                            _shakeController,
                            _boardPulseController,
                          ]),
                          builder: (context, child) {
                            final pulse = math.sin(
                              _boardPulseController.value * math.pi,
                            );
                            final bump =
                                1 + 0.02 * pulse * _boardPulseController.value;
                            return Transform.translate(
                              offset: Offset(_shakeTween.value, 0),
                              child: Transform.scale(
                                scale: bump,
                                alignment: Alignment.center,
                                child: child,
                              ),
                            );
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final side = math.min(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return Center(
                                child: SizedBox(
                                  key: _boardKey,
                                  width: side,
                                  height: side,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: GameWidget<Stage2FlameGame>(
                                      game: _flameGame,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildBlockTray(context),
                      if (_session.isGameOver) ...[
                        const SizedBox(height: 8),
                        _buildGameOverPanel(context),
                      ],
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Column(
                        children: <Widget>[
                          for (final f in _flyouts)
                            _FloatingFlyoutLabel(
                              key: ValueKey<String>(f.id),
                              item: f,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHud(BuildContext context) {
    return AnimatedBuilder(
      animation: _scoreBumpController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scoreBumpAnim.value,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, color: Color(0xFFFFD60A), size: 28),
          Text(
            '${_session.score}',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: 3.0,
              shadows: [
                Shadow(
                  color: ArcadeShellTheme.glowCyan.withValues(alpha: 0.8),
                  blurRadius: 20,
                ),
                Shadow(
                  color: ArcadeShellTheme.neonPink.withValues(alpha: 0.4),
                  blurRadius: 40,
                ),
                const Shadow(
                  color: Color(0x88000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComboBanner() {
    final msg = _comboMessage ?? '';
    return AnimatedBuilder(
      animation: _comboPopController,
      builder: (context, child) {
        final t = Curves.elasticOut.transform(_comboPopController.value);
        final scale = (0.6 + 0.55 * t).clamp(0.0, 1.35);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFFFF9500),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66FF9500),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildBlockTray(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: ArcadeShellTheme.electricBlue.withValues(alpha: 0.12),
            border: Border.all(
              color: ArcadeShellTheme.glowCyan.withValues(alpha: 0.45),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              const BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: ArcadeShellTheme.neonPink.withValues(alpha: 0.12),
                blurRadius: 18,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Drag blocks onto the board',
                style: GoogleFonts.orbitron(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(_session.queue.items.length, (
                    index,
                  ) {
                    final shape = _session.queue.items[index];
                    final selected = _session.selectedQueueIndex == index;
                    final isDragging = _draggingQueueIndex == index;
                    final child = _BlockTraySlot(
                      shape: shape,
                      color:
                          Stage2FlameGame.blockColors[shape.colorType] ??
                          Colors.grey,
                      selected: selected && _draggingQueueIndex == null,
                      dragging: isDragging,
                      enabled: !_session.isGameOver,
                      onTap: () {
                        unawaited(_haptics.onTraySelect());
                        unawaited(_audio.onTraySelect());
                        setState(() {
                          _session = _session.selectQueueIndex(index);
                        });
                        _syncFlameBoard();
                      },
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _session.isGameOver
                          ? child
                          : Draggable<int>(
                              data: index,
                              dragAnchorStrategy:
                                  (draggable, context, position) =>
                                      _captureDragFeedbackAnchor(
                                        context,
                                        position,
                                      ),
                              feedback: Material(
                                type: MaterialType.transparency,
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: _dragIsOverBoard,
                                  builder: (context, isOverBoard, child) {
                                    return Opacity(
                                      key: ValueKey<String>(
                                        'block-tray-drag-feedback-$index',
                                      ),
                                      opacity: isOverBoard ? 0.0 : 1.0,
                                      child: child,
                                    );
                                  },
                                  child: Transform.scale(
                                    scale: 1.22,
                                    child: _BlockTraySlot(
                                      shape: shape,
                                      color:
                                          Stage2FlameGame.blockColors[shape
                                              .colorType] ??
                                          Colors.grey,
                                      selected: true,
                                      dragging: true,
                                      enabled: true,
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                              ),
                              onDragStarted: () {
                                unawaited(_haptics.onTraySelect());
                                unawaited(_audio.onTraySelect());
                                unawaited(_audio.onDragTick());
                                _dragPointerGlobalPosition = null;
                                _setDragIsOverBoard(false);
                                setState(() {
                                  _draggingQueueIndex = index;
                                  _session = _session.selectQueueIndex(index);
                                });
                                _syncFlameBoard();
                              },
                              onDragUpdate: (details) {
                                _handleDragPointerUpdate(
                                  index,
                                  details.globalPosition,
                                );
                              },
                              onDraggableCanceled: (_, _) {
                                _clearDragState();
                              },
                              onDragEnd: (_) {
                                _setDragIsOverBoard(false);
                                _dragPointerGlobalPosition = null;
                                _dragFeedbackAnchorOffset = Offset.zero;
                                _flameGame.clearPreview();
                                if (mounted && _draggingQueueIndex != null) {
                                  setState(() {
                                    _draggingQueueIndex = null;
                                  });
                                }
                              },
                              childWhenDragging: Opacity(
                                opacity: 0.22,
                                child: child,
                              ),
                              child: child,
                            ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverPanel(BuildContext context) {
    const ink = Color(0xFFE8F4FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1038).withValues(alpha: 0.94),
            const Color(0xFF0D1528).withValues(alpha: 0.97),
          ],
        ),
        border: Border.all(
          color: ArcadeShellTheme.glowCyan.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: ArcadeShellTheme.neonPink.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'GAME OVER',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ink,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'No valid moves remain.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ink.withValues(alpha: 0.75), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${_session.score}',
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              color: ArcadeShellTheme.glowCyan,
              fontWeight: FontWeight.w900,
              fontSize: 44,
              height: 1.0,
              shadows: [
                Shadow(
                  color: ArcadeShellTheme.neonPink.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
                const Shadow(
                  color: Color(0x88000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
          Text(
            'FINAL SCORE',
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              color: ink.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rewarded continue once, or end run for a fresh board.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ink.withValues(alpha: 0.65), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _continueLoading ? null : _onContinueRewardedTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ArcadeShellTheme.glowCyan,
                    side: BorderSide(
                      color: ArcadeShellTheme.glowCyan.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _continueLoading ? 'LOADING...' : 'CONTINUE',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _onEndRunTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: ArcadeShellTheme.neonPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 8,
                    shadowColor: ArcadeShellTheme.neonPink.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  child: Text(
                    'END RUN',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlyoutItem {
  const _FlyoutItem({
    required this.id,
    required this.text,
    required this.color,
  });

  final String id;
  final String text;
  final Color color;
}

class _BoardDropPreview {
  const _BoardDropPreview({
    required this.queueIndex,
    required this.shape,
    required this.originX,
    required this.originY,
    required this.isValid,
  });

  final int queueIndex;
  final BlockShape shape;
  final int originX;
  final int originY;
  final bool isValid;
}

class _ShapeBounds {
  const _ShapeBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final int minX;
  final int maxX;
  final int minY;
  final int maxY;
}

class _FloatingFlyoutLabel extends StatelessWidget {
  const _FloatingFlyoutLabel({super.key, required this.item});

  final _FlyoutItem item;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 820),
      curve: Curves.easeOut,
      builder: (context, t, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Opacity(
            opacity: (1 - t * 0.88).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -40 * t),
              child: Text(
                item.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: item.color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      color: item.color.withValues(alpha: 0.6),
                      blurRadius: 16,
                    ),
                    const Shadow(
                      color: Color(0x88000000),
                      blurRadius: 4,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BlockTraySlot extends StatelessWidget {
  const _BlockTraySlot({
    required this.shape,
    required this.color,
    required this.selected,
    required this.dragging,
    required this.enabled,
    required this.onTap,
  });

  final BlockShape shape;
  final Color color;
  final bool selected;
  final bool dragging;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedScale(
        scale: dragging ? 1.08 : (selected ? 1.06 : 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.elasticOut,
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: dragging
                ? const Color(0x26FFFFFF)
                : (selected ? const Color(0x18FFFFFF) : Colors.transparent),
            border: Border.all(
              color: dragging
                  ? ArcadeShellTheme.glowCyan.withValues(alpha: 0.9)
                  : (selected
                        ? Colors.white.withValues(alpha: 0.55)
                        : Colors.transparent),
              width: dragging ? 2.4 : 1.4,
            ),
            boxShadow: dragging
                ? [
                    BoxShadow(
                      color: ArcadeShellTheme.glowCyan.withValues(alpha: 0.34),
                      blurRadius: 18,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: _MiniShapePreview(cells: shape.cells, color: color),
          ),
        ),
      ),
    );
  }
}

class _MiniShapePreview extends StatelessWidget {
  const _MiniShapePreview({required this.cells, required this.color});

  final List<GridPoint> cells;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) {
      return const SizedBox.shrink();
    }
    var minX = cells.first.dx;
    var maxX = cells.first.dx;
    var minY = cells.first.dy;
    var maxY = cells.first.dy;
    for (final c in cells) {
      minX = math.min(minX, c.dx);
      maxX = math.max(maxX, c.dx);
      minY = math.min(minY, c.dy);
      maxY = math.max(maxY, c.dy);
    }
    final gw = maxX - minX + 1;
    final gh = maxY - minY + 1;
    const cell = 18.0; // slightly larger
    final w = gw * cell;
    final h = gh * cell;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          for (final c in cells)
            Positioned(
              left: (c.dx - minX) * cell,
              top: (c.dy - minY) * cell,
              width: cell - 1,
              height: cell - 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: color,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
