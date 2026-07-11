import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../core/neon_theme.dart';
import '../data/levels.dart';
import '../logic/pop_detector.dart';
import '../presentation/controllers/game_controller.dart';
import 'block_component.dart';

/// Bàn PopStar: tap 1 ô, nổ nhóm cùng màu liền kề (≥2), cột rơi + dồn trái —
/// có animation (pop nở + hạt, rơi/trượt bằng tween). Không dùng Flame
/// TapDetector — tap đến từ GestureDetector ở game_screen.dart qua [handleTap].
class PopStarGame extends FlameGame {
  PopStarGame(this.controller);

  final GameController controller;

  late int rows;
  late int cols;
  late double cellSize;
  double _boardLeft = 0;
  double _boardTop = 0;

  /// Nguồn sự thật cho logic (màu từng ô). Đồng bộ với [_blocks] sau mỗi bước.
  late List<List<int?>> colorGrid;

  /// Component tương ứng từng ô (null nếu trống) — để animate di chuyển.
  late List<List<BlockComponent?>> _blocks;

  List<List<int?>>? _undoGrid;
  final _rng = Random();

  /// Đang diễn hoạt → chặn tap để tránh chồng bước.
  bool _animating = false;

  /// Đếm ngược cửa sổ combo; hết → reset combo ở controller.
  double _comboTimer = 0;

  static const double _popDur = 0.16;
  static const double _fallDur = 0.26;

  // Nền canvas trong suốt để tray sáng + nền candy phía sau lộ qua (mặc định
  // FlameGame tô đen).
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    final level = controller.currentLevel;
    rows = level.rows;
    cols = level.cols;
    colorGrid = List.generate(
      rows,
      (_) => List.generate(cols, (_) => _rng.nextInt(level.colorCount)),
    );
    controller.activeGame = this;
    _layout();
    _rebuildBoard();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _layout();
      _rebuildBoard();
    }
  }

  void _layout() {
    cellSize = min(size.x / cols, size.y / rows);
    _boardLeft = (size.x - cols * cellSize) / 2;
    _boardTop = (size.y - rows * cellSize) / 2;
  }

  Vector2 _cellCenter(int r, int c) => Vector2(
    _boardLeft + c * cellSize + cellSize / 2,
    _boardTop + r * cellSize + cellSize / 2,
  );

  /// Ô (row, col) tại [pos] trong không gian game, hoặc null nếu ngoài bàn.
  Point<int>? cellAt(Vector2 pos) {
    final col = ((pos.x - _boardLeft) / cellSize).floor();
    final row = ((pos.y - _boardTop) / cellSize).floor();
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    return Point(row, col);
  }

  /// [pos] toạ độ trong không gian game (đã convert từ local position ở UI).
  void handleTap(Vector2 pos) {
    if (_animating) return;
    final cell = cellAt(pos);
    if (cell == null) return;
    _tryPop(cell.x, cell.y);
  }

  // --- preview nhóm khi giữ/kéo (G1) ---
  final Set<Point<int>> _preview = {};
  TextComponent? _previewBadge;

  /// Highlight nhóm cùng màu tại [pos] + badge điểm dự kiến (đúng hệ số combo).
  void previewGroup(Vector2 pos) {
    if (_animating) return;
    final cell = cellAt(pos);
    final g = cell == null
        ? const <Point<int>>{}
        : findConnectedGroup(colorGrid, cell.x, cell.y);
    if (g.length < 2) {
      clearPreview();
      return;
    }
    if (g.length == _preview.length && _preview.containsAll(g)) return;
    _setHighlight(false);
    _preview
      ..clear()
      ..addAll(g);
    _setHighlight(true);
    final nextMult = (1 + controller.comboCount.value * 0.5).clamp(
      1.0,
      GameController.comboMax,
    );
    final predicted = (scoreForGroup(g.length) * nextMult).round();
    var cx = 0.0, cy = 0.0;
    for (final p in g) {
      final v = _cellCenter(p.x, p.y);
      cx += v.x;
      cy += v.y;
    }
    _previewBadge?.removeFromParent();
    _previewBadge = TextComponent(
      text: '+$predicted',
      anchor: Anchor.center,
      position: Vector2(cx / g.length, cy / g.length),
      priority: 120,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: cellSize * 0.4,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: NeonTheme.ink, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
    add(_previewBadge!);
  }

  void clearPreview() {
    if (_preview.isEmpty && _previewBadge == null) return;
    _setHighlight(false);
    _preview.clear();
    _previewBadge?.removeFromParent();
    _previewBadge = null;
  }

  void _setHighlight(bool on) {
    for (final p in _preview) {
      _blocks[p.x][p.y]?.highlighted = on;
    }
  }

  void _tryPop(int row, int col) {
    final group = findConnectedGroup(colorGrid, row, col);
    if (group.length < 2) return;
    _saveUndo();
    final gained = controller.registerPop(scoreForGroup(group.length));
    _comboTimer = GameController.comboWindow;
    _spawnScorePopup(row, col, gained, controller.comboMultiplier.value);
    _clearAndCollapse(group);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (controller.comboCount.value > 0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0) controller.resetCombo();
    }
  }

  void triggerBomb(int row, int col) {
    if (_animating) return;
    _saveUndo();
    final cells = <Point<int>>{};
    for (var r = row - 1; r <= row + 1; r++) {
      for (var c = col - 1; c <= col + 1; c++) {
        if (r >= 0 &&
            r < rows &&
            c >= 0 &&
            c < cols &&
            colorGrid[r][c] != null) {
          cells.add(Point(r, c));
        }
      }
    }
    if (cells.isEmpty) return;
    _clearAndCollapse(cells);
  }

  /// Xoá [cells]: animate pop từng ô + hạt, rồi rơi/dồn bằng tween, cuối cùng
  /// đồng bộ colorGrid và kiểm tra kết thúc.
  void _clearAndCollapse(Set<Point<int>> cells) {
    _animating = true;
    for (final p in cells) {
      colorGrid[p.x][p.y] = null;
      final b = _blocks[p.x][p.y];
      _blocks[p.x][p.y] = null;
      if (b != null) {
        _spawnBurst(b.position.clone(), NeonTheme.gemColors[b.colorIndex]);
        b.add(
          SequenceEffect([
            ScaleEffect.to(Vector2.all(1.3), EffectController(duration: 0.07)),
            ScaleEffect.to(
              Vector2.zero(),
              EffectController(duration: _popDur - 0.07),
            ),
          ], onComplete: b.removeFromParent),
        );
      }
    }
    // dời tween sau khi pop bắt đầu, cho cảm giác nổ trước rồi mới rơi
    add(
      TimerComponent(
        period: _popDur,
        removeOnFinish: true,
        onTick: _collapseAnimated,
      ),
    );
  }

  void _collapseAnimated() {
    // gravity trong cột: dồn block xuống đáy (giữ thứ tự trên→dưới).
    for (var c = 0; c < cols; c++) {
      final vals = <BlockComponent?>[];
      for (var r = 0; r < rows; r++) {
        if (_blocks[r][c] != null) vals.add(_blocks[r][c]);
      }
      final pad = rows - vals.length;
      for (var r = 0; r < rows; r++) {
        _blocks[r][c] = r < pad ? null : vals[r - pad];
      }
    }
    // dồn cột không rỗng sang trái.
    final nonEmpty = <int>[];
    for (var c = 0; c < cols; c++) {
      if (List.generate(rows, (r) => _blocks[r][c]).any((b) => b != null)) {
        nonEmpty.add(c);
      }
    }
    if (nonEmpty.length != cols) {
      final newBlocks = List.generate(
        rows,
        (_) => List<BlockComponent?>.filled(cols, null),
      );
      for (var k = 0; k < nonEmpty.length; k++) {
        for (var r = 0; r < rows; r++) {
          newBlocks[r][k] = _blocks[r][nonEmpty[k]];
        }
      }
      _blocks = newBlocks;
    }
    // tween mọi block về vị trí mới + đồng bộ colorGrid.
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final b = _blocks[r][c];
        colorGrid[r][c] = b?.colorIndex;
        if (b == null) continue;
        final target = _cellCenter(r, c);
        if ((b.position - target).length2 > 0.01) {
          b.add(
            MoveToEffect(
              target,
              EffectController(duration: _fallDur, curve: Curves.easeOutBack),
            ),
          );
        }
      }
    }
    add(
      TimerComponent(
        period: _fallDur,
        removeOnFinish: true,
        onTick: () {
          _animating = false;
          _checkEnd();
        },
      ),
    );
  }

  /// Popup "+điểm" (kèm "xN" nếu combo) bay lên rồi biến mất tại ô vừa tap.
  void _spawnScorePopup(int row, int col, int gained, double mult) {
    final combo = mult > 1.0;
    final multTxt = mult == mult.roundToDouble()
        ? mult.toStringAsFixed(0)
        : mult.toStringAsFixed(1);
    final txt = combo ? '+$gained  x$multTxt' : '+$gained';
    final color = combo ? NeonTheme.orange : Colors.white;
    final comp = TextComponent(
      text: txt,
      anchor: Anchor.center,
      position: _cellCenter(row, col),
      priority: 100,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: cellSize * (combo ? 0.42 : 0.34),
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: NeonTheme.ink, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
    comp.add(
      MoveByEffect(
        Vector2(0, -cellSize * 1.3),
        EffectController(duration: 0.6, curve: Curves.easeOut),
      ),
    );
    comp.add(
      ScaleEffect.by(
        Vector2.all(1.25),
        EffectController(duration: 0.14, alternate: true),
      ),
    );
    comp.add(RemoveEffect(delay: 0.6));
    add(comp);
  }

  void _spawnBurst(Vector2 at, Color color) {
    add(
      ParticleSystemComponent(
        position: at,
        particle: Particle.generate(
          count: 10,
          generator: (i) {
            final a = _rng.nextDouble() * pi * 2;
            final speed = 60 + _rng.nextDouble() * 90;
            return AcceleratedParticle(
              acceleration: Vector2(0, 220),
              speed: Vector2(cos(a), sin(a)) * speed,
              lifespan: 0.5,
              child: CircleParticle(
                radius: cellSize * 0.08,
                paint: Paint()..color = color.withValues(alpha: 0.9),
              ),
            );
          },
        ),
      ),
    );
  }

  void shuffleBoard() {
    if (_animating) return;
    _saveUndo();
    final values = [
      for (final row in colorGrid)
        for (final v in row) ?v,
    ];
    values.shuffle(_rng);
    var i = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (colorGrid[r][c] != null) colorGrid[r][c] = values[i++];
      }
    }
    _rebuildBoard();
    _checkEnd();
  }

  bool undo() {
    if (_animating) return false;
    final saved = _undoGrid;
    if (saved == null) return false;
    colorGrid = saved;
    _undoGrid = null;
    _rebuildBoard();
    return true;
  }

  void _saveUndo() {
    _undoGrid = colorGrid.map((row) => List<int?>.from(row)).toList();
  }

  void _checkEnd() {
    final remaining = colorGrid
        .expand((row) => row)
        .where((v) => v != null)
        .length;
    if (remaining == 0) {
      controller.addScore(clearBoardBonus);
      controller.checkEnd(true);
    } else if (!hasAnyMovableGroup(colorGrid)) {
      controller.checkEnd(false);
    }
  }

  /// Dựng lại toàn bộ bàn tức thì (load/resize/shuffle/undo) — không animation.
  void _rebuildBoard() {
    children.whereType<BlockComponent>().toList().forEach(remove);
    _blocks = List.generate(
      rows,
      (_) => List<BlockComponent?>.filled(cols, null),
    );
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final color = colorGrid[r][c];
        if (color == null) continue;
        final b = BlockComponent(
          colorIndex: color,
          position: _cellCenter(r, c),
          size: Vector2.all(cellSize),
        );
        _blocks[r][c] = b;
        add(b);
      }
    }
  }
}
