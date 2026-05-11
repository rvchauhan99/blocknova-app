import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../../game_core/game_session.dart';
import '../../game_core/block_shape.dart';

class Stage2FlameGame extends FlameGame with TapCallbacks {
  Stage2FlameGame({
    required this.onCellTap,
    GameSession? initialSession,
  }) : _session = initialSession ?? GameSession.stage2Start();

  final Future<void> Function(int x, int y) onCellTap;

  GameSession _session;
  Set<int> _placedFlashKeys = <int>{};
  Set<int> _clearedFlashKeys = <int>{};
  int? _invalidTapKey;

  double _placementPulse = 0;
  double _clearPulse = 0;

  int? previewX;
  int? previewY;
  BlockShape? previewShape;

  BoardPainterComponent? _painter;

  GameSession get visualSession => _session;

  double get placementPulse => _placementPulse;
  double get clearPulse => _clearPulse;

  static const Color _emptyBase = Color(0x38091A2E); // Translucent empty cells
  static const Color _emptyBorder = Color(0x55001028); // Inner rim on empty cells
  static const Color _invalid = Color(0xFFFF007F);

  static const Map<BlockColorType, Color> blockColors = {
    BlockColorType.red: Color(0xFFFF4B4B),
    BlockColorType.green: Color(0xFF4CD964),
    BlockColorType.blue: Color(0xFF3399FF),
    BlockColorType.yellow: Color(0xFFFFD60A),
    BlockColorType.purple: Color(0xFFCC73E1),
    BlockColorType.orange: Color(0xFFFF9500),
    BlockColorType.cyan: Color(0xFF64D2FF),
  };

  void setPreview(BlockShape shape, int x, int y) {
    previewShape = shape;
    previewX = x;
    previewY = y;
  }

  void clearPreview() {
    previewShape = null;
    previewX = null;
    previewY = null;
  }

  void applySnapshot({
    required GameSession session,
    required Set<int> placedFlashKeys,
    required Set<int> clearedFlashKeys,
    required int? invalidTapKey,
  }) {
    _session = session;
    _placedFlashKeys = Set<int>.from(placedFlashKeys);
    _clearedFlashKeys = Set<int>.from(clearedFlashKeys);
    _invalidTapKey = invalidTapKey;

    if (placedFlashKeys.isNotEmpty) {
      _placementPulse = 1;
    }
    if (clearedFlashKeys.isNotEmpty) {
      _clearPulse = 1;
    }
  }

  Color colorForCell(int x, int y) {
    final board = visualSession.board;
    final key = board.keyFor(x, y);
    if (_invalidTapKey == key) {
      return _invalid;
    }
    
    final colorType = board.colorAt(x, y);
    if (colorType != null) {
      return blockColors[colorType] ?? _emptyBase;
    }
    
    return _emptyBase;
  }

  bool cellHasInvalidBorder(int x, int y) =>
      _invalidTapKey == visualSession.board.keyFor(x, y);

  @visibleForTesting
  Future<void> testingSimulateCellTap(int x, int y) => onCellTap(x, y);

  @override
  Color backgroundColor() => const Color(0x00000000); // Transparent to let Flutter background show

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
    final p = BoardPainterComponent(gameRef: this);
    _painter = p;
    world.add(p);
    if (hasLayout && canvasSize.x > 0 && canvasSize.y > 0) {
      p.size = canvasSize.clone();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final p = _painter;
    if (p != null && size.x > 0 && size.y > 0) {
      p.size = Vector2(size.x, size.y);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_placementPulse > 0) {
      _placementPulse = math.max(0, _placementPulse - dt * 3.0); // Slower, more impactful pulse
    }
    if (_clearPulse > 0) {
      _clearPulse = math.max(0, _clearPulse - dt * 2.5); // Slower explosion
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (visualSession.isGameOver) {
      return;
    }
    if (!hasLayout) {
      return;
    }
    final n = visualSession.board.size;
    final s = canvasSize;
    if (s.x <= 0 || s.y <= 0) {
      return;
    }
    final cellW = s.x / n;
    final cellH = s.y / n;
    final p = event.canvasPosition;
    final x = (p.x / cellW).floor().clamp(0, n - 1);
    final y = (p.y / cellH).floor().clamp(0, n - 1);
    unawaited(onCellTap(x, y));
  }
}

class BoardPainterComponent extends PositionComponent {
  BoardPainterComponent({required this.gameRef});

  final Stage2FlameGame gameRef;

  @override
  void render(Canvas canvas) {
    final session = gameRef.visualSession;
    final n = session.board.size;
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    
    // Calculate cell dimensions
    final cellW = size.x / n;
    final cellH = size.y / n;
    final gap = 1.5;
    final r = math.min(10.0, math.min(cellW, cellH) * 0.2);

    // Draw Board Background (Glassmorphic panel)
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Radius.circular(r + 8),
    );
    
    // Outer glow (electric cyan + magenta bloom)
    final glowPaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    canvas.drawRRect(boardRect.inflate(4), glowPaint);
    final glowMagenta = Paint()
      ..color = const Color(0xFFE040FB).withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawRRect(boardRect.inflate(6), glowMagenta);

    // Glass panel
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1E1B4B).withValues(alpha: 0.88),
          const Color(0xFF0C1024).withValues(alpha: 0.96),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawRRect(boardRect, bgPaint);

    // Rim + inner shadow for glass thickness
    final glassBorder = Paint()
      ..color = const Color(0x55B026FF).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(boardRect, glassBorder);

    // Draw cells
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final left = x * cellW + gap;
        final top = y * cellH + gap;
        final w = cellW - gap * 2;
        final h = cellH - gap * 2;
        
        final occupied = session.board.isOccupied(x, y);
        final key = session.board.keyFor(x, y);
        final isCleared = gameRef._clearedFlashKeys.contains(key);
        final isPlaced = gameRef._placedFlashKeys.contains(key);

        bool isPreview = false;
        if (!occupied && gameRef.previewShape != null) {
          for (final c in gameRef.previewShape!.cells) {
            if (gameRef.previewX! + c.dx == x && gameRef.previewY! + c.dy == y) {
              isPreview = true;
              break;
            }
          }
        }
        
        // Calculate dynamic scaling for animations
        double scale = 1.0;
        if (isPlaced) {
          scale = 1.0 + (math.sin(gameRef.placementPulse * math.pi) * 0.15);
        } else if (isCleared) {
          scale = gameRef.clearPulse;
        }

        final cw = w * scale;
        final ch = h * scale;
        final cx = left + (w - cw) / 2;
        final cy = top + (h - ch) / 2;
        
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx, cy, cw, ch),
          Radius.circular(r * scale),
        );

        if (!occupied && !isCleared && gameRef._invalidTapKey != key && !isPreview) {
          // Empty cell: dark indent
          final fill = Paint()..color = Stage2FlameGame._emptyBase;
          canvas.drawRRect(rect, fill);
          
          final innerShadow = Paint()
            ..color = Stage2FlameGame._emptyBorder
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawRRect(rect.deflate(1), innerShadow);
        } else if (isCleared || occupied || isPreview) {
          // Filled cell: Chunky 3D Premium Block
          Color baseColor;
          double alphaOffset = 1.0;
          if (isPreview) {
            baseColor = Stage2FlameGame.blockColors[gameRef.previewShape!.colorType]!;
            alphaOffset = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(DateTime.now().millisecondsSinceEpoch / 150)); // Pulsing preview
            scale *= 1.05; // Slightly larger during preview drag
          } else {
            baseColor = gameRef.colorForCell(x, y);
          }
          
          if (isCleared) {
            baseColor = Color.lerp(baseColor, Colors.white, 1 - gameRef.clearPulse)!;
            alphaOffset = gameRef.clearPulse;
          } else if (isPlaced) {
            baseColor = Color.lerp(baseColor, Colors.white, gameRef.placementPulse * 0.8)!;
          }
          
          // Re-calculate rect in case scale changed (e.g. preview mode)
          final finalCw = w * scale;
          final finalCh = h * scale;
          final finalCx = left + (w - finalCw) / 2;
          final finalCy = top + (h - finalCh) / 2;
          final finalRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(finalCx, finalCy, finalCw, finalCh),
            Radius.circular(r * scale),
          );

          // Base color with radial inner glow (jewel effect)
          final fill = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.2, -0.2),
              radius: 0.8,
              colors: [
                Color.lerp(baseColor, Colors.white, 0.3)!.withValues(alpha: alphaOffset),
                baseColor.withValues(alpha: alphaOffset),
              ],
            ).createShader(Rect.fromLTWH(finalCx, finalCy, finalCw, finalCh));
          
          if (isPreview) {
            // Add a massive back glow for preview snapping
            final previewGlow = Paint()
              ..color = baseColor.withValues(alpha: 0.4)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
            canvas.drawRRect(finalRect.inflate(4), previewGlow);
          }
          
          canvas.drawRRect(finalRect, fill);

          // 3D Top-Left Light Bevel
          final lightBevel = Paint()
            ..color = const Color(0x88FFFFFF).withValues(alpha: alphaOffset * 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 * scale;
          
          canvas.save();
          canvas.clipRect(Rect.fromLTWH(finalCx, finalCy, finalCw, finalCh * 0.5));
          canvas.drawRRect(finalRect.deflate(1.5 * scale), lightBevel);
          canvas.restore();

          // 3D Bottom-Right Dark Bevel
          final darkBevel = Paint()
            ..color = const Color(0x66000000).withValues(alpha: alphaOffset * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0 * scale;
          
          canvas.save();
          canvas.clipRect(Rect.fromLTWH(finalCx, finalCy + finalCh * 0.5, finalCw, finalCh * 0.5));
          canvas.drawRRect(finalRect.deflate(1.5 * scale), darkBevel);
          canvas.restore();
          
          // Glossy top highlight
          final highlightRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(finalCx + finalCw * 0.1, finalCy + finalCh * 0.05, finalCw * 0.8, finalCh * 0.25),
            Radius.circular(r * scale * 0.5),
          );
          final highlight = Paint()..color = const Color(0x44FFFFFF).withValues(alpha: alphaOffset * 0.25);
          canvas.drawRRect(highlightRect, highlight);
        }

        if (gameRef.cellHasInvalidBorder(x, y)) {
          final border = Paint()
            ..color = const Color(0xFFFF3B30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;
          canvas.drawRRect(rect.inflate(1), border);
        }
      }
    }
  }
}
