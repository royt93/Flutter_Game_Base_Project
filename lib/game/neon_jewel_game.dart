import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../core/audio_manager.dart';
import '../core/neon_theme.dart';
import '../data/levels.dart';
import '../logic/gem_data.dart';
import '../logic/match_detector.dart';
import '../presentation/controllers/game_controller.dart';
import 'effects.dart';
import 'gem_component.dart';

/// Game match-3 neon chính (Flame). Sở hữu lưới GemComponent và điều phối
/// toàn bộ vòng lặp: swap → match → nổ → trọng lực → cascade.
class NeonJewelGame extends FlameGame with TapCallbacks, DragCallbacks {
  final GameController controller;
  final int rows;
  final int cols;
  final int colorCount;

  /// Callback báo kết quả ván ('win' | 'lose') cho tầng UI hiển thị dialog.
  final void Function(String result) onGameEnd;

  NeonJewelGame({
    required this.controller,
    required this.rows,
    required this.cols,
    required this.colorCount,
    required this.onGameEnd,
  });

  final _rnd = math.Random();
  late List<List<GemComponent?>> grid;
  late double cellSize;
  late Vector2 boardOrigin;

  /// Lớp chứa gem — tách riêng để rung (shake) toàn bàn mà không ảnh hưởng nền.
  late final PositionComponent boardLayer;

  GemComponent? _selected;
  bool _busy = false;

  @override
  Color backgroundColor() => const Color(0x00000000); // để nền gradient Flutter lộ ra

  @override
  Future<void> onLoad() async {
    await NeonFx.ensureInit(); // pre-render ảnh glow 1 lần (tránh blur mỗi frame)
    _layout();
    add(NeonBackground(area: size, palette: NeonTheme.gemColors, rnd: _rnd)
      ..priority = -10);
    boardLayer = PositionComponent()..priority = 0;
    add(boardLayer);
    boardLayer.add(BoardFrame(
      rows: rows,
      cols: cols,
      cellSize: cellSize,
      origin: boardOrigin,
    )..priority = -2);
    _buildJelly();
    boardLayer.add(JellyLayer(
      jelly: jelly,
      rows: rows,
      cols: cols,
      cellSize: cellSize,
      origin: boardOrigin,
    )..priority = -1);
    _fillInitialBoard();
    if (!_hasPossibleMove()) await _doShuffle();
  }

  /// Lưới jelly (0 = không, >0 = số lớp). Khởi tạo theo cấu hình màn.
  late List<List<int>> jelly;

  void _buildJelly() {
    jelly = List.generate(rows, (_) => List<int>.filled(cols, 0));
    int total = 0;
    bool has(int r, int c) {
      switch (controller.level.jelly) {
        case JellyPattern.none:
          return false;
        case JellyPattern.all:
          return true;
        case JellyPattern.checker:
          return (r + c).isEven;
        case JellyPattern.center:
          final r0 = (rows - 4) ~/ 2, c0 = (cols - 4) ~/ 2;
          return r >= r0 && r < r0 + 4 && c >= c0 && c < c0 + 4;
      }
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (has(r, c)) {
          jelly[r][c] = 1;
          total++;
        }
      }
    }
    controller.jellyTotal = total;
  }

  // Trauma-based shake: luôn tính offset từ gốc (0,0) và tự giảm về 0 →
  // KHÔNG BAO GIỜ trôi/lệch tâm dù nhiều shake chồng nhau.
  double _trauma = 0;
  static const double _maxShake = 11;

  @override
  void update(double dt) {
    super.update(dt);
    if (_trauma > 0) {
      final amt = _trauma * _trauma;
      boardLayer.position = Vector2(
        (_rnd.nextDouble() * 2 - 1) * _maxShake * amt,
        (_rnd.nextDouble() * 2 - 1) * _maxShake * amt,
      );
      _trauma = math.max(0, _trauma - dt * 2.4);
      if (_trauma == 0) boardLayer.position = Vector2.zero();
    }

    // Gợi ý khi đứng yên quá lâu (stuck)
    if (!_busy && _selected == null) {
      _idle += dt;
      if (_idle > 4.0 && _hintGems.isEmpty) _triggerHint();
    }
  }

  void _layout() {
    // chừa lề 16px mỗi bên + 16px cho khung panel → board không khít mép
    final availW = size.x - 32 - 8;
    cellSize = availW / cols;
    final boardW = cellSize * cols;
    final boardH = cellSize * rows;
    boardOrigin = Vector2((size.x - boardW) / 2, (size.y - boardH) / 2);
  }

  Vector2 _cellCenter(int r, int c) => Vector2(
        boardOrigin.x + c * cellSize + cellSize / 2,
        boardOrigin.y + r * cellSize + cellSize / 2,
      );

  GemColor _randomColor() => GemColor.values[_rnd.nextInt(colorCount)];

  void _fillInitialBoard() {
    grid = List.generate(rows, (_) => List<GemComponent?>.filled(cols, null));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        GemColor color;
        // tránh tạo match-3 ngay từ đầu
        do {
          color = _randomColor();
        } while (_wouldMatchAt(r, c, color));
        final g = GemComponent(
          color: color,
          type: GemType.normal,
          row: r,
          col: c,
          position: _cellCenter(r, c),
          cellSize: cellSize,
        );
        grid[r][c] = g;
        // pop-in xếp tầng theo đường chéo cho màn mở đầu "wow"
        g.scale = Vector2.zero();
        g.add(ScaleEffect.to(
          Vector2.all(1),
          EffectController(
            duration: 0.35,
            curve: Curves.easeOutBack,
            startDelay: (r + c) * 0.03,
          ),
        ));
        boardLayer.add(g);
      }
    }
  }

  bool _wouldMatchAt(int r, int c, GemColor color) {
    if (c >= 2 && grid[r][c - 1]?.color == color && grid[r][c - 2]?.color == color) {
      return true;
    }
    if (r >= 2 && grid[r - 1][c]?.color == color && grid[r - 2][c]?.color == color) {
      return true;
    }
    return false;
  }

  List<List<GemColor?>> _colorGrid() => [
        for (int r = 0; r < rows; r++)
          [for (int c = 0; c < cols; c++) grid[r][c]?.color],
      ];

  // --------------------------------------------------------------------------
  // Tương tác chạm
  // --------------------------------------------------------------------------
  @override
  void onTapDown(TapDownEvent event) {
    if (_busy) return;
    _resetIdle();
    final cell = _cellAtPosition(event.localPosition);
    if (cell == null) return;
    final gem = grid[cell.row][cell.col];
    if (gem == null) return;

    if (_selected == null) {
      _selected = gem..selected = true;
    } else if (identical(_selected, gem)) {
      gem.selected = false;
      _selected = null;
    } else if (_isAdjacent(_selected!, gem)) {
      final a = _selected!..selected = false;
      _selected = null;
      _trySwap(a, gem);
    } else {
      _selected!.selected = false;
      _selected = gem..selected = true;
    }
  }

  Cell? _cellAtPosition(Vector2 p) {
    final lx = p.x - boardOrigin.x;
    final ly = p.y - boardOrigin.y;
    if (lx < 0 || ly < 0) return null;
    final c = lx ~/ cellSize;
    final r = ly ~/ cellSize;
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
    return Cell(r, c);
  }

  bool _isAdjacent(GemComponent a, GemComponent b) =>
      (a.row == b.row && (a.col - b.col).abs() == 1) ||
      (a.col == b.col && (a.row - b.row).abs() == 1);

  // --- Vuốt để đổi gem (swipe-to-swap, giống game gốc) ---
  Cell? _dragCell;
  Vector2 _dragAccum = Vector2.zero();

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_busy) {
      _dragCell = null;
      return;
    }
    _resetIdle();
    _dragCell = _cellAtPosition(event.localPosition);
    _dragAccum = Vector2.zero();
    _selected?.selected = false;
    _selected = null;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_dragCell == null || _busy) return;
    _dragAccum += event.localDelta;
    if (_dragAccum.length < cellSize * 0.4) return;

    int dr = 0, dc = 0;
    if (_dragAccum.x.abs() > _dragAccum.y.abs()) {
      dc = _dragAccum.x > 0 ? 1 : -1;
    } else {
      dr = _dragAccum.y > 0 ? 1 : -1;
    }
    final from = _dragCell!;
    _dragCell = null; // chỉ kích hoạt 1 lần mỗi cử chỉ
    final r = from.row + dr, c = from.col + dc;
    if (r < 0 || r >= rows || c < 0 || c >= cols) return;
    final a = grid[from.row][from.col];
    final b = grid[r][c];
    if (a != null && b != null) _trySwap(a, b);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragCell = null;
  }

  // --------------------------------------------------------------------------
  // Vòng lặp game
  // --------------------------------------------------------------------------
  Future<void> _trySwap(GemComponent a, GemComponent b) async {
    _busy = true;
    // try/finally: dù có lỗi giữa chừng, _busy LUÔN được mở lại → bàn không bao giờ kẹt.
    try {
      await _animateSwap(a, b);
      _swapInGrid(a, b);

      // Combo kích hoạt khi: cả 2 đều special, HOẶC 1 trong 2 là rainbow.
      final comboTrigger = (a.type != GemType.normal && b.type != GemType.normal) ||
          a.type == GemType.rainbow ||
          b.type == GemType.rainbow;
      final matches = MatchDetector.findMatches(_colorGrid());

      if (matches.isEmpty && !comboTrigger) {
        // không hợp lệ → đảo lại
        await _animateSwap(a, b);
        _swapInGrid(a, b);
      } else {
        controller.useMove();
        if (comboTrigger) {
          AudioManager.maybe?.playSpecial();
          final base = _comboCells(a, b);
          final expanded = _expandSpecials(base);
          _shake((expanded.length * 0.5).clamp(4.0, 14.0));
          await _clearCells(expanded);
          controller.addScore(expanded.length, 2);
          await _applyGravityAndRefill();
        }
        await _resolveAll();
        await _ensurePlayable();
        _finishMove();
      }
    } finally {
      _busy = false;
      _selected = null;
    }
  }

  /// Tập ô bị xóa khi swap 2 gem special (combo). Trả về set "gốc" (sẽ được
  /// _expandSpecials mở rộng tiếp theo các special dính trong đó).
  Set<Cell> _comboCells(GemComponent a, GemComponent b) {
    final ta = a.type, tb = b.type;
    final pos = Cell(b.row, b.col);
    final cells = <Cell>{Cell(a.row, a.col), pos};

    bool isRainbow(GemType t) => t == GemType.rainbow;

    // rainbow + rainbow → cả bàn
    if (isRainbow(ta) && isRainbow(tb)) {
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          cells.add(Cell(r, c));
        }
      }
      return cells;
    }
    // rainbow + (khác) → toàn bộ gem cùng màu gem kia, nâng cấp theo loại
    if (isRainbow(ta) || isRainbow(tb)) {
      final other = isRainbow(ta) ? b : a;
      final targetColor = other.color;
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (grid[r][c]?.color == targetColor) {
            cells.add(Cell(r, c));
            if (other.type == GemType.stripedH || other.type == GemType.stripedV) {
              for (int k = 0; k < cols; k++) {
                cells.add(Cell(r, k));
              }
              for (int k = 0; k < rows; k++) {
                cells.add(Cell(k, c));
              }
            } else if (other.type == GemType.bomb) {
              for (int dr = -1; dr <= 1; dr++) {
                for (int dc = -1; dc <= 1; dc++) {
                  final rr = r + dr, cc = c + dc;
                  if (rr >= 0 && rr < rows && cc >= 0 && cc < cols) {
                    cells.add(Cell(rr, cc));
                  }
                }
              }
            }
          }
        }
      }
      return cells;
    }

    bool striped(GemType t) => t == GemType.stripedH || t == GemType.stripedV;
    // bomb + bomb → 5x5
    if (ta == GemType.bomb && tb == GemType.bomb) {
      _addArea(cells, pos, 2);
    } else if ((ta == GemType.bomb && striped(tb)) ||
        (striped(ta) && tb == GemType.bomb)) {
      // striped + bomb → 3 hàng + 3 cột
      for (int dr = -1; dr <= 1; dr++) {
        final r = pos.row + dr;
        if (r >= 0 && r < rows) {
          for (int c = 0; c < cols; c++) {
            cells.add(Cell(r, c));
          }
        }
      }
      for (int dc = -1; dc <= 1; dc++) {
        final c = pos.col + dc;
        if (c >= 0 && c < cols) {
          for (int r = 0; r < rows; r++) {
            cells.add(Cell(r, c));
          }
        }
      }
    } else if (striped(ta) && striped(tb)) {
      // striped + striped → 1 hàng + 1 cột (chữ thập)
      for (int c = 0; c < cols; c++) {
        cells.add(Cell(pos.row, c));
      }
      for (int r = 0; r < rows; r++) {
        cells.add(Cell(r, pos.col));
      }
    } else {
      // 1 bomb / 1 striped còn lại: kích hoạt theo loại tại pos
      _addArea(cells, pos, 1);
    }
    return cells;
  }

  void _addArea(Set<Cell> cells, Cell center, int radius) {
    for (int dr = -radius; dr <= radius; dr++) {
      for (int dc = -radius; dc <= radius; dc++) {
        final r = center.row + dr, c = center.col + dc;
        if (r >= 0 && r < rows && c >= 0 && c < cols) cells.add(Cell(r, c));
      }
    }
  }

  /// Nếu bàn không còn nước đi hợp lệ → tự xáo (tối đa vài lần) để người chơi
  /// không bị kẹt.
  Future<void> _ensurePlayable() async {
    int guard = 0;
    while (!_hasPossibleMove() && guard < 5) {
      guard++;
      // báo cho người chơi biết bàn tự xáo (vì hết nước đi)
      add(ComboTextComponent(
        text: 'SHUFFLE!',
        color: NeonTheme.purple,
        position: Vector2(size.x / 2, size.y * 0.42),
        maxWidth: size.x * 0.9,
      )..priority = 70);
      await _doShuffle();
      await _resolveAll();
    }
  }

  bool _hasPossibleMove() => _findMove() != null;

  /// Tìm 1 nước swap hợp lệ (tạo match). Trả về cặp ô, hoặc null nếu bí.
  List<Cell>? _findMove() {
    final g = _colorGrid();
    bool matchAfterSwap(int r1, int c1, int r2, int c2) {
      final t = g[r1][c1];
      g[r1][c1] = g[r2][c2];
      g[r2][c2] = t;
      final has = MatchDetector.hasMatch(g);
      final t2 = g[r1][c1];
      g[r1][c1] = g[r2][c2];
      g[r2][c2] = t2;
      return has;
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (g[r][c] == null) continue;
        if (c + 1 < cols && matchAfterSwap(r, c, r, c + 1)) {
          return [Cell(r, c), Cell(r, c + 1)];
        }
        if (r + 1 < rows && matchAfterSwap(r, c, r + 1, c)) {
          return [Cell(r, c), Cell(r + 1, c)];
        }
      }
    }
    return null;
  }

  // --- Gợi ý khi người chơi bị stuck ---
  double _idle = 0;
  List<GemComponent> _hintGems = [];

  void _resetIdle() {
    _idle = 0;
    _clearHint();
  }

  void _clearHint() {
    for (final g in _hintGems) {
      g.hint = false;
    }
    _hintGems = [];
  }

  void _triggerHint() {
    final move = _findMove();
    if (move == null) return;
    _hintGems = [
      for (final cell in move)
        if (grid[cell.row][cell.col] != null) grid[cell.row][cell.col]!
    ];
    for (final g in _hintGems) {
      g.hint = true;
    }
  }

  Future<void> _resolveAll() async {
    int combo = 0;
    while (true) {
      final matches = MatchDetector.findMatches(_colorGrid());
      if (matches.isEmpty) break;
      combo++;

      final toClear = <Cell>{};
      final newSpecials = <Cell, GemType>{};
      for (final g in matches) {
        toClear.addAll(g.cells);
        if (g.special != GemType.normal && g.specialAt != null) {
          newSpecials[g.specialAt!] = g.special;
        }
      }
      // Giao điểm T/L → bomb (ưu tiên hơn striped tại ô đó)
      for (final bomb in MatchDetector.bombCells(matches)) {
        newSpecials[bomb] = GemType.bomb;
      }

      // kích hoạt special đã có sẵn nằm trong vùng xóa (chain reaction)
      var expanded = _expandSpecials(toClear);
      // những ô sắp biến thành special mới thì giữ lại, không xóa
      expanded = expanded..removeWhere((cell) => newSpecials.containsKey(cell));

      await _clearCells(expanded);
      controller.addScore(expanded.length, combo);
      AudioManager.maybe?.playNote(combo); // combo cao → nốt cao dần
      if (combo >= 2) _spawnComboText(combo);

      // tạo gem special mới — kèm hiệu ứng "ra đời" nổi bật
      if (newSpecials.isNotEmpty) AudioManager.maybe?.playSpecial();
      newSpecials.forEach((cell, type) {
        final g = grid[cell.row][cell.col];
        if (g == null) return;
        g.type = type;
        final col = type == GemType.rainbow ? Colors.white : neonColorOf(g.color);
        add(ShockwaveComponent(
          position: _cellCenter(cell.row, cell.col),
          color: col,
          maxRadius: cellSize * 1.4,
          duration: 0.35,
        )..priority = 55);
        g.add(ScaleEffect.to(
          Vector2.all(1.35),
          EffectController(
              duration: 0.13, alternate: true, curve: Curves.easeOut),
        ));
      });

      await _applyGravityAndRefill();
    }
  }

  /// Mở rộng tập ô xóa bằng cách kích hoạt các gem special bên trong nó.
  Set<Cell> _expandSpecials(Set<Cell> initial) {
    final result = <Cell>{...initial};
    final queue = <Cell>[...initial];
    while (queue.isNotEmpty) {
      final cell = queue.removeLast();
      final g = grid[cell.row][cell.col];
      if (g == null) continue;
      final extra = <Cell>[];
      switch (g.type) {
        case GemType.stripedH:
          _addBeam(_cellCenter(cell.row, 0), _cellCenter(cell.row, cols - 1),
              neonColorOf(g.color));
          for (int c = 0; c < cols; c++) {
            extra.add(Cell(cell.row, c));
          }
          break;
        case GemType.stripedV:
          _addBeam(_cellCenter(0, cell.col), _cellCenter(rows - 1, cell.col),
              neonColorOf(g.color));
          for (int r = 0; r < rows; r++) {
            extra.add(Cell(r, cell.col));
          }
          break;
        case GemType.bomb:
          add(ShockwaveComponent(
            position: _cellCenter(cell.row, cell.col),
            color: neonColorOf(g.color),
            maxRadius: cellSize * 2.2,
          )..priority = 50);
          _flash(neonColorOf(g.color), peak: 0.14);
          _shake(8);
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              final r = cell.row + dr, c = cell.col + dc;
              if (r >= 0 && r < rows && c >= 0 && c < cols) extra.add(Cell(r, c));
            }
          }
          break;
        case GemType.rainbow:
          add(ShockwaveComponent(
            position: _cellCenter(cell.row, cell.col),
            color: Colors.white,
            maxRadius: cellSize * 4,
          )..priority = 50);
          _flash(Colors.white, peak: 0.4);
          _shake(12);
          for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
              if (grid[r][c]?.color == g.color) extra.add(Cell(r, c));
            }
          }
          break;
        case GemType.normal:
          break;
      }
      for (final e in extra) {
        if (!result.contains(e)) {
          result.add(e);
          queue.add(e);
        }
      }
    }
    return result;
  }

  Future<void> _clearCells(Set<Cell> cells) async {
    final gems = <GemComponent>[];
    for (final cell in cells) {
      final g = grid[cell.row][cell.col];
      if (g == null) continue;
      // cập nhật mục tiêu: thu thập màu + phá jelly tại ô này
      final wasJelly = jelly[cell.row][cell.col] > 0;
      if (wasJelly) jelly[cell.row][cell.col]--;
      controller.registerClear(g.color, wasJelly);
      gems.add(g);
      grid[cell.row][cell.col] = null;
    }
    if (gems.isNotEmpty) {
      // sóng xung kích tại trọng tâm cụm + rung bàn theo số gem
      var centroid = Vector2.zero();
      for (final g in gems) {
        centroid += g.position;
      }
      centroid /= gems.length.toDouble();
      add(ShockwaveComponent(
        position: centroid,
        color: neonColorOf(gems.first.color),
        maxRadius: cellSize * (1.4 + gems.length * 0.25),
      )..priority = 50);
      _shake((gems.length * 0.8).clamp(2.0, 14.0));
    }

    final futures = <Future>[];
    for (final g in gems) {
      _spawnBurst(g.position.clone(), neonColorOf(g.color));
      futures.add(_run(
        g,
        ScaleEffect.to(
          Vector2.zero(),
          EffectController(duration: 0.18, curve: Curves.easeIn),
        ),
      ));
    }
    await Future.wait(futures);
    for (final g in gems) {
      g.removeFromParent();
    }
  }

  Future<void> _applyGravityAndRefill() async {
    final futures = <Future>[];
    for (int c = 0; c < cols; c++) {
      int writeRow = rows - 1;
      // dồn gem hiện có xuống đáy
      for (int r = rows - 1; r >= 0; r--) {
        final g = grid[r][c];
        if (g != null) {
          if (writeRow != r) {
            grid[writeRow][c] = g;
            grid[r][c] = null;
            g.row = writeRow;
            g.col = c;
            futures.add(_run(
              g,
              MoveToEffect(
                _cellCenter(writeRow, c),
                EffectController(duration: 0.26, curve: Curves.bounceOut),
              ),
            ));
          }
          writeRow--;
        }
      }
      // sinh gem mới rơi từ phía trên
      final newCount = writeRow + 1;
      for (int i = 0; i < newCount; i++) {
        final targetRow = writeRow - i;
        final startRow = -1 - i;
        final g = GemComponent(
          color: _randomColor(),
          type: GemType.normal,
          row: targetRow,
          col: c,
          position: _cellCenter(startRow, c),
          cellSize: cellSize,
        );
        grid[targetRow][c] = g;
        g.scale = Vector2.all(0.4);
        g.add(ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.28, curve: Curves.easeOutBack),
        ));
        boardLayer.add(g);
        futures.add(_run(
          g,
          MoveToEffect(
            _cellCenter(targetRow, c),
            EffectController(duration: 0.32, curve: Curves.bounceOut),
          ),
        ));
      }
    }
    await Future.wait(futures);
  }

  void _finishMove() {
    final result = controller.checkEnd();
    if (result != null) {
      onGameEnd(result);
    }
  }

  // --------------------------------------------------------------------------
  // Helpers animation & particle
  // --------------------------------------------------------------------------
  Future<void> _animateSwap(GemComponent a, GemComponent b) async {
    final pa = a.position.clone();
    final pb = b.position.clone();
    await Future.wait([
      _run(a, MoveToEffect(pb, EffectController(duration: 0.15))),
      _run(b, MoveToEffect(pa, EffectController(duration: 0.15))),
    ]);
  }

  void _swapInGrid(GemComponent a, GemComponent b) {
    grid[a.row][a.col] = b;
    grid[b.row][b.col] = a;
    final tr = a.row, tc = a.col;
    a.row = b.row;
    a.col = b.col;
    b.row = tr;
    b.col = tc;
  }

  Future<void> _run(Component target, Effect effect) {
    final completer = Completer<void>();
    effect.onComplete = completer.complete;
    target.add(effect);
    return completer.future;
  }

  void _spawnBurst(Vector2 position, Color color) {
    // Particle nhẹ: không MaskFilter, dùng blend cộng (BlendMode.plus) tạo cảm giác
    // neon rực mà rẻ. Giảm count 16→9 để mượt khi nổ cụm lớn.
    final particle = Particle.generate(
      count: 9,
      lifespan: 0.5,
      generator: (i) {
        final angle = _rnd.nextDouble() * math.pi * 2;
        final speed = 60 + _rnd.nextDouble() * 150;
        final velocity = Vector2(math.cos(angle), math.sin(angle))..scale(speed);
        return AcceleratedParticle(
          acceleration: Vector2(0, 160),
          speed: velocity,
          child: ComputedParticle(
            renderer: (canvas, p) {
              final t = 1 - p.progress;
              final paint = Paint()
                ..color = color.withValues(alpha: t)
                ..blendMode = BlendMode.plus;
              canvas.drawCircle(Offset.zero, cellSize * 0.11 * t + 1, paint);
            },
          ),
        );
      },
    );
    add(ParticleSystemComponent(particle: particle, position: position)..priority = 40);
  }

  /// Booster: xáo trộn màu toàn bàn (đảm bảo không tạo match sẵn). Có pop + rung.
  Future<void> shuffleBoard() async {
    if (_busy) return;
    _busy = true;
    try {
      await _doShuffle();
    } finally {
      _busy = false;
    }
  }

  /// Lõi xáo bàn (không quản lý _busy — dùng nội bộ & cho auto-shuffle).
  Future<void> _doShuffle() async {
    final cells = <Cell>[];
    final colors = <GemColor>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final g = grid[r][c];
        if (g != null) {
          cells.add(Cell(r, c));
          colors.add(g.color);
        }
      }
    }
    // xáo tới khi không có match sẵn (tối đa 20 lần thử)
    for (int attempt = 0; attempt < 20; attempt++) {
      colors.shuffle(_rnd);
      final test =
          List.generate(rows, (_) => List<GemColor?>.filled(cols, null));
      for (int i = 0; i < cells.length; i++) {
        test[cells[i].row][cells[i].col] = colors[i];
      }
      if (!MatchDetector.hasMatch(test)) break;
    }
    final futures = <Future>[];
    for (int i = 0; i < cells.length; i++) {
      final g = grid[cells[i].row][cells[i].col]!;
      g.color = colors[i];
      g.type = GemType.normal;
      g.scale = Vector2.all(0.5);
      futures.add(_run(
          g,
          ScaleEffect.to(Vector2.all(1),
              EffectController(duration: 0.3, curve: Curves.elasticOut))));
    }
    _shake(6);
    await Future.wait(futures);
  }

  /// Tăng "trauma" rung — vòng update sẽ áp dụng & tự giảm về 0 (không trôi tâm).
  void _shake(double intensity) {
    _trauma = math.min(1.0, _trauma + intensity / 14);
  }

  void _addBeam(Vector2 from, Vector2 to, Color color) {
    add(BeamComponent(from: from, to: to, color: color)..priority = 60);
  }

  void _spawnComboText(int combo) {
    final epic = combo >= 6;
    final color = NeonTheme.gemColors[combo % NeonTheme.gemColors.length];
    final fontSize = (24 + combo * 4).clamp(24, epic ? 46 : 40).toDouble();
    final label = epic ? 'WOMBO COMBO x$combo!' : 'COMBO x$combo!';
    add(ComboTextComponent(
      text: label,
      color: color,
      position: Vector2(size.x / 2, size.y * 0.4),
      fontSize: fontSize,
      maxWidth: size.x * 0.92,
      epic: epic,
      duration: epic ? 1.3 : 0.9,
    )..priority = 70);
    if (epic) {
      _flash(color, peak: 0.32);
      _shake(12);
    } else if (combo >= 4) {
      _flash(color, peak: 0.18);
    }
  }

  /// Chớp sáng toàn màn (rainbow / combo lớn).
  void _flash(Color color, {double peak = 0.3}) {
    add(FlashOverlay(area: size, color: color, peak: peak)..priority = 80);
  }
}
