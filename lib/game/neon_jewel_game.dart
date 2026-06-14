import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/audio_manager.dart';
import '../core/neon_theme.dart';
import '../data/levels.dart';
import '../logic/gem_data.dart';
import '../logic/match_detector.dart';
import '../presentation/controllers/game_controller.dart';
import 'effects.dart';
import 'gem_component.dart';

/// Chế độ booster đang kích hoạt (chờ người chơi chạm bàn).
enum BoosterMode { none, hammer, swap, bomb, colorBlast, joker }

/// Game match-3 neon chính (Flame). Sở hữu lưới GemComponent và điều phối
/// toàn bộ vòng lặp: swap → match → nổ → trọng lực → cascade.
class NeonJewelGame extends FlameGame with TapCallbacks, DragCallbacks {
  final GameController controller;
  final int rows;
  final int cols;
  final int colorCount;

  /// Callback báo kết quả ván ('win' | 'lose') cho tầng UI hiển thị dialog.
  final void Function(String result) onGameEnd;

  /// Gọi khi 1 booster được DÙNG thành công → UI trừ số lượng booster đó.
  final void Function(BoosterMode mode)? onBoosterUsed;

  /// Versus: gọi sau mỗi nước đi hoàn tất với combo đỉnh của nước đó → tầng
  /// trên gửi "rác" sang đối thủ khi combo lớn.
  final void Function(int combo)? onMoveResolved;

  /// Versus: tắt SFX của bàn này (tránh 2 bàn chồng âm) — vẫn giữ hiệu ứng hình.
  final bool muteSfx;

  NeonJewelGame({
    required this.controller,
    required this.rows,
    required this.cols,
    required this.colorCount,
    required this.onGameEnd,
    this.onBoosterUsed,
    this.onMoveResolved,
    this.muteSfx = false,
  });

  /// Audio SFX của bàn (null khi [muteSfx] — versus tắt để không chồng âm 2 bàn).
  AudioManager? get _sfx => muteSfx ? null : AudioManager.maybe;

  /// Hàng rác chờ áp (áp khi engine rảnh để không phá cascade đang chạy).
  int _pendingJunk = 0;
  int get pendingJunk => _pendingJunk; // cho test

  /// Versus: nhận [n] hàng rác từ đối thủ (xếp hàng, áp ở [update] khi rảnh).
  void receiveJunk(int n) {
    if (n > 0) _pendingJunk += n;
  }

  BoosterMode boosterMode = BoosterMode.none;
  Cell? _swapA; // ô đầu tiên khi dùng booster Swap

  void armBooster(BoosterMode m) {
    boosterMode = m;
    _swapA = null;
  }

  void disarmBooster() {
    boosterMode = BoosterMode.none;
    _swapA = null;
  }

  final _rnd = math.Random();
  late List<List<GemComponent?>> grid;
  late double cellSize;
  late Vector2 boardOrigin;

  /// Lớp chứa gem — tách riêng để rung (shake) toàn bàn mà không ảnh hưởng nền.
  late final PositionComponent boardLayer;

  GemComponent? _selected;
  bool _busy = false;
  bool _ended = false; // ván đã kết thúc (thắng/thua) → chặn input

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
    _buildObstacle();
    boardLayer.add(ObstacleLayer(
      obstacle: obstacle,
      type: controller.level.obstacle,
      rows: rows,
      cols: cols,
      cellSize: cellSize,
      origin: boardOrigin,
    )..priority = -1);
    _fillInitialBoard();
    _placeIngredients();
    if (!_hasPossibleMove()) await _doShuffle();
  }

  /// Lưới obstacle (0 = không, >0 = số lớp). Theo cấu hình màn.
  late List<List<int>> obstacle;

  ObstacleType get _obstacleType => controller.level.obstacle;

  // Spread (chocolate): cờ "đã chặn được lan trong lượt này" + trần số ô (chống
  // khoá bàn). Mỗi lượt KHÔNG chặn → lan thêm 1 ô.
  bool _spreadHitThisMove = false;
  static const int _spreadCap = 16;

  void _buildObstacle() {
    obstacle = List.generate(rows, (_) => List<int>.filled(cols, 0));
    final type = controller.level.obstacle;
    if (type == ObstacleType.none) {
      controller.obstacleTotal.value = 0;
      return;
    }
    // spread (chocolate): seed nhỏ 2 ô giữa, KHÔNG là mục tiêu (objective = score).
    if (type == ObstacleType.spread) {
      final cr = rows ~/ 2, cc = cols ~/ 2;
      for (final s in [Cell(cr, cc - 1), Cell(cr, cc)]) {
        obstacle[s.row][s.col] = 1;
      }
      controller.obstacleTotal.value = 0; // không tính vào điều kiện thắng
      return;
    }
    int total = 0;
    final pattern = controller.level.obstaclePattern;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (patternHas(pattern, r, c, rows, cols)) {
          obstacle[r][c] = 1;
          total++;
        }
      }
    }
    controller.obstacleTotal.value = total;
  }

  /// Số ingredient tối đa cùng lúc trên bàn (Drop Down).
  static const int _maxConcurrentIngredients = 2;

  /// Drop Down: đặt ingredient ban đầu (tối đa [_maxConcurrentIngredients]);
  /// phần còn lại sinh dần qua [_replenishIngredients].
  void _placeIngredients() {
    if (controller.level.objective != ObjectiveType.dropDown) return;
    final initial =
        controller.level.dropTarget.clamp(0, _maxConcurrentIngredients);
    final chosen = <int>{};
    while (chosen.length < initial && chosen.length < cols) {
      chosen.add(_rnd.nextInt(cols));
    }
    for (final c in chosen) {
      grid[0][c]?.isIngredient = true;
    }
  }

  /// Sinh thêm ingredient ở hàng trên khi còn thiếu so với mục tiêu, giữ tối đa
  /// [_maxConcurrentIngredients] trên bàn (dòng chảy ingredient liên tục).
  void _replenishIngredients() {
    if (controller.level.objective != ObjectiveType.dropDown) return;
    final remaining = controller.level.dropTarget - controller.dropped.value;
    if (remaining <= 0) return;
    var active = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c]?.isIngredient ?? false) active++;
      }
    }
    final desired =
        remaining < _maxConcurrentIngredients ? remaining : _maxConcurrentIngredients;
    if (active >= desired) return;
    final free = [
      for (int c = 0; c < cols; c++)
        if (grid[0][c] != null && !grid[0][c]!.isIngredient) c
    ]..shuffle(_rnd);
    for (final c in free) {
      if (active >= desired) break;
      grid[0][c]!.isIngredient = true;
      add(ShockwaveComponent(
        position: _cellCenter(0, c),
        color: const Color(0xFFFFC83D),
        maxRadius: cellSize * 1.3,
        duration: 0.3,
      )..priority = 50);
      active++;
    }
  }

  /// Lưới jelly (0 = không, >0 = số lớp). Khởi tạo theo cấu hình màn.
  late List<List<int>> jelly;

  void _buildJelly() {
    jelly = List.generate(rows, (_) => List<int>.filled(cols, 0));
    int total = 0;
    final pattern = controller.level.jelly;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (patternHas(pattern, r, c, rows, cols)) {
          jelly[r][c] = 1;
          total++;
        }
      }
    }
    controller.jellyTotal.value = total;
  }

  // Trauma-based shake: luôn tính offset từ gốc (0,0) và tự giảm về 0 →
  // KHÔNG BAO GIỜ trôi/lệch tâm dù nhiều shake chồng nhau.
  double _trauma = 0;
  static const double _maxShake = 11;

  double _timeAccum = 0; // tích luỹ dt cho đồng hồ Time Attack

  // Slow-motion ngắn khi combo lớn (wombo) — làm chậm MỌI hiệu ứng Flame.
  double _timeScale = 1.0;
  double _slowmoLeft = 0;

  /// Kích hoạt slow-mo trong [seconds] giây (thời gian thực).
  void _triggerSlowmo(double seconds) {
    _slowmoLeft = math.max(_slowmoLeft, seconds);
    _timeScale = 0.32;
  }

  @override
  void update(double dt) {
    // slow-mo: đếm ngược theo thời gian thực, làm chậm super.update (hiệu ứng)
    if (_slowmoLeft > 0) {
      _slowmoLeft -= dt;
      if (_slowmoLeft <= 0) _timeScale = 1.0;
    }
    super.update(dt * _timeScale);

    // Rhythm: tiến đồng hồ nhịp theo thời gian thực (không dính slow-mo).
    if (!_ended) controller.tickRhythm(dt);

    // Versus: áp hàng rác đang chờ khi engine rảnh (không phá cascade).
    if (!_busy && !_ended && _pendingJunk > 0) {
      final n = _pendingJunk.clamp(1, rows - 1);
      _pendingJunk = 0;
      _applyJunk(n);
    }

    // Time Attack: đếm ngược thời gian, hết giờ → kết thúc ván.
    if (!_ended &&
        controller.level.objective == ObjectiveType.timeAttack) {
      _timeAccum += dt;
      while (_timeAccum >= 1.0 && controller.timeLeft.value > 0) {
        _timeAccum -= 1.0;
        controller.tickTime(1);
      }
      // Hết giờ → kết thúc, NHƯNG chờ cascade hiện tại xong (_busy) để không
      // end giữa chuỗi nổ (tránh race score/dialog).
      if (controller.timeLeft.value <= 0 && !_busy) _finishMove();
    }

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
    if (!_busy && !_ended && _selected == null) {
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
          [
            for (int c = 0; c < cols; c++) _matchColorAt(r, c),
          ],
      ];

  /// Màu dùng cho match-detection: ingredient & stone (còn lớp) bị loại (null)
  /// → không tham gia match.
  GemColor? _matchColorAt(int r, int c) {
    final g = grid[r][c];
    if (g == null || g.isIngredient) return null;
    // stone & spread (chocolate) phủ kín → gem không tham gia match
    if (obstacle[r][c] > 0 &&
        (_obstacleType == ObstacleType.stone ||
            _obstacleType == ObstacleType.spread)) {
      return null;
    }
    return g.color;
  }

  /// Gem có bị khoá không cho người chơi chủ động đổi chỗ?
  /// (ingredient luôn khoá; chain/stone khoá khi còn lớp; ice KHÔNG khoá.)
  bool _swapLocked(int r, int c) {
    final g = grid[r][c];
    if (g == null) return false;
    if (g.isIngredient) return true;
    if (obstacle[r][c] > 0) {
      return _obstacleType == ObstacleType.chain ||
          _obstacleType == ObstacleType.stone ||
          _obstacleType == ObstacleType.spread;
    }
    return false;
  }

  // --------------------------------------------------------------------------
  // Tương tác chạm
  // --------------------------------------------------------------------------
  @override
  void onTapDown(TapDownEvent event) {
    if (_busy || _ended) return;
    _resetIdle();
    final cell = _cellAtPosition(event.localPosition);
    if (cell == null) return;
    final gem = grid[cell.row][cell.col];
    if (gem == null) return;

    // Đang kích hoạt booster → xử lý theo loại
    if (boosterMode != BoosterMode.none) {
      _handleBoosterTap(cell);
      return;
    }

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
    if (_busy || _ended) {
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
    if (_ended) return;
    // gem bị khoá (ingredient/chain/stone) không cho đổi chỗ
    if (_swapLocked(a.row, a.col) || _swapLocked(b.row, b.col)) return;
    _busy = true;
    var consumed = false; // đã tiêu 1 lượt?
    // try/finally: dù lỗi giữa chừng, _busy mở lại + LUÔN kiểm tra kết thúc ván.
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
        consumed = true;
        controller.useMove();
        controller.judgeRhythmBeat(); // Rhythm: phán định đúng/lệch nhịp tại nước đi
        if (controller.isRhythm.value && controller.lastBeatJudge.value == 1) {
          // đúng nhịp → nốt nhạc cao dần theo groove (phản hồi "khớp" nghe đã tai)
          _sfx?.playNote(controller.groove.value.clamp(1, 24));
        }
        _spreadHitThisMove = false; // theo dõi có chặn được chocolate lan không
        if (comboTrigger) {
          _sfx?.playSpecial();
          final base = _comboCells(a, b);
          final expanded = _expandSpecials(base);
          _shake((expanded.length * 0.5).clamp(4.0, 14.0));
          await _clearCells(expanded);
          controller.addScore(expanded.length, 2);
          await _applyGravityAndRefill();
        }
        await _settle();
        await _maybeGrowSpread(); // không chặn được → chocolate lan 1 ô
        await _ensurePlayable();
        // Trọng lực động: cứ N lượt thì bàn tự lật (đảo cột).
        if (controller.consumeGravityFlip()) {
          await _doColumnFlip();
        }
      }
    } finally {
      _busy = false;
      _selected = null;
      // LUÔN kiểm tra kết thúc nếu đã tiêu lượt (kể cả khi có lỗi ở trên)
      if (consumed) _finishMove();
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
        // bỏ qua nước cần đổi ô đang bị khoá (ingredient/chain/stone) — nếu không
        // game tưởng còn nước đi nhưng người chơi không thực hiện được → kẹt.
        if (_swapLocked(r, c)) continue;
        if (c + 1 < cols &&
            !_swapLocked(r, c + 1) &&
            matchAfterSwap(r, c, r, c + 1)) {
          return [Cell(r, c), Cell(r, c + 1)];
        }
        if (r + 1 < rows &&
            !_swapLocked(r + 1, c) &&
            matchAfterSwap(r, c, r + 1, c)) {
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
      // Giai điệu: màu nổi trội của bước này → bậc âm; combo → leo thang;
      // khoá theo world/stage → đổi tông. (ngũ cung + hợp âm khi wombo)
      final domColor = matches
          .reduce((a, b) => b.cells.length > a.cells.length ? b : a)
          .color
          .index;
      _sfx?.playMelodic(
          combo: combo, colorIndex: domColor, keyIndex: controller.melodyKey);
      if (combo >= 2) _spawnComboText(combo);
      // Time Attack: combo lớn thưởng thêm giây
      if (combo >= 4 &&
          controller.level.objective == ObjectiveType.timeAttack) {
        final bonus = combo - 2; // combo4→+2s, 5→+3s...
        controller.addTime(bonus);
        _spawnTimeBonus(bonus);
      }

      // tạo gem special mới — kèm hiệu ứng "ra đời" nổi bật
      if (newSpecials.isNotEmpty) _sfx?.playSpecial();
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

  /// Giải quyết toàn bộ sau 1 nước đi: resolve match → thu ingredient (Drop Down)
  /// → resolve lại cho tới khi bàn ổn định.
  Future<void> _settle() async {
    await _resolveAll();
    if (controller.level.objective == ObjectiveType.dropDown) {
      while (await _collectIngredients()) {
        await _resolveAll();
      }
      _replenishIngredients(); // bổ sung ingredient nếu còn thiếu mục tiêu
    }
  }

  /// Thu các ingredient đang nằm ở hàng đáy → tính điểm mục tiêu Drop Down,
  /// rồi gravity bù lại. Trả về true nếu có thu được (để caller resolve tiếp).
  Future<bool> _collectIngredients() async {
    var collectedAny = false;
    while (true) {
      final atBottom = <GemComponent>[];
      for (int c = 0; c < cols; c++) {
        final g = grid[rows - 1][c];
        if (g != null && g.isIngredient) {
          grid[rows - 1][c] = null;
          atBottom.add(g);
          controller.registerDrop();
        }
      }
      if (atBottom.isEmpty) break;
      collectedAny = true;
      final futures = <Future>[];
      for (final g in atBottom) {
        _spawnBurst(g.position.clone(), NeonTheme.lime);
        add(ShockwaveComponent(
          position: g.position.clone(),
          color: NeonTheme.lime,
          maxRadius: cellSize * 1.7,
          duration: 0.35,
        )..priority = 50);
        futures.add(_run(
          g,
          ScaleEffect.to(
            Vector2.zero(),
            EffectController(duration: 0.2, curve: Curves.easeIn),
          ),
        ));
      }
      _shake(6);
      await Future.wait(futures);
      for (final g in atBottom) {
        g.removeFromParent();
      }
      await _applyGravityAndRefill();
    }
    return collectedAny;
  }

  /// Chocolate lan: nếu lượt vừa rồi KHÔNG clear ô kề chocolate nào (không chặn)
  /// → lan sang 1 ô gem thường kề ngẫu nhiên. Có trần [_spreadCap] chống khoá bàn.
  Future<void> _maybeGrowSpread() async {
    if (_obstacleType != ObstacleType.spread || _spreadHitThisMove) return;
    final spreadCells = <Cell>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (obstacle[r][c] > 0) spreadCells.add(Cell(r, c));
      }
    }
    if (spreadCells.isEmpty || spreadCells.length >= _spreadCap) return;
    final candidates = <Cell>{};
    for (final cell in spreadCells) {
      for (final n in [
        Cell(cell.row - 1, cell.col),
        Cell(cell.row + 1, cell.col),
        Cell(cell.row, cell.col - 1),
        Cell(cell.row, cell.col + 1),
      ]) {
        if (n.row < 0 || n.row >= rows || n.col < 0 || n.col >= cols) continue;
        if (obstacle[n.row][n.col] > 0) continue;
        final g = grid[n.row][n.col];
        if (g != null && !g.isIngredient && g.type == GemType.normal) {
          candidates.add(n);
        }
      }
    }
    if (candidates.isEmpty) return;
    final target = (candidates.toList()..shuffle(_rnd)).first;
    obstacle[target.row][target.col] = 1;
    _shake(4);
    add(ShockwaveComponent(
      position: _cellCenter(target.row, target.col),
      color: const Color(0xFFB05CFF),
      maxRadius: cellSize * 1.25,
      duration: 0.35,
    )..priority = 48);
    await Future.delayed(const Duration(milliseconds: 170));
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
    // obstacle bị tổn hại theo tập ô vừa clear (ice: trực tiếp; chain/stone: kề)
    _damageObstacles(cells);
    final gems = <GemComponent>[];
    var luckyCount = 0;
    for (final cell in cells) {
      final g = grid[cell.row][cell.col];
      if (g == null) continue;
      // stone còn lớp → KHÔNG xóa gem (chỉ bị damage qua _damageObstacles)
      if (obstacle[cell.row][cell.col] > 0 &&
          _obstacleType == ObstacleType.stone) {
        continue;
      }
      // cập nhật mục tiêu: thu thập màu + phá jelly tại ô này
      final wasJelly = jelly[cell.row][cell.col] > 0;
      if (wasJelly) jelly[cell.row][cell.col]--;
      controller.registerClear(g.color, wasJelly);
      if (g.isLucky) luckyCount++;
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
      _spawnBurst(g.position.clone(), neonColorOf(g.color),
          big: g.type != GemType.normal);
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
    if (luckyCount > 0) _applyLuckyBonus(luckyCount);
  }

  /// Gem may mắn vừa nổ → thưởng: điểm + xu + biến [count] gem thường ngẫu
  /// nhiên thành special ngẫu nhiên (bất ngờ kiểu mystery candy).
  void _applyLuckyBonus(int count) {
    controller.addScore(count * 8, 2);
    controller.addCoins(count * 5);
    _flash(Colors.white, peak: 0.18);
    add(ComboTextComponent(
      text: 'LUCKY!',
      color: NeonTheme.yellow,
      position: Vector2(size.x / 2, size.y * 0.32),
      fontSize: 30,
      maxWidth: size.x * 0.7,
      duration: 0.9,
    )..priority = 71);
    final candidates = <Cell>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final g = grid[r][c];
        if (g != null &&
            g.type == GemType.normal &&
            !g.isIngredient &&
            obstacle[r][c] == 0) {
          candidates.add(Cell(r, c));
        }
      }
    }
    candidates.shuffle(_rnd);
    const specials = [GemType.stripedH, GemType.stripedV, GemType.bomb];
    for (int i = 0; i < count && i < candidates.length; i++) {
      final cell = candidates[i];
      final g = grid[cell.row][cell.col]!;
      g.type = specials[_rnd.nextInt(specials.length)];
      g.isLucky = false;
      add(ShockwaveComponent(
        position: _cellCenter(cell.row, cell.col),
        color: Colors.white,
        maxRadius: cellSize * 1.4,
        duration: 0.35,
      )..priority = 55);
      g.add(ScaleEffect.to(
        Vector2.all(1.3),
        EffectController(duration: 0.13, alternate: true, curve: Curves.easeOut),
      ));
    }
  }

  /// Gỡ obstacle theo tập ô vừa clear:
  /// - ice: giảm 1 lớp ở chính ô bị clear (gem đã được match)
  /// - chain/stone: giảm 1 lớp ở ô KỀ (hoặc chính ô) bị clear
  void _damageObstacles(Set<Cell> cleared) {
    final type = _obstacleType;
    if (type == ObstacleType.none) return;
    final reduce = <Cell>{};
    if (type == ObstacleType.ice) {
      for (final cell in cleared) {
        if (obstacle[cell.row][cell.col] > 0) reduce.add(cell);
      }
    } else {
      for (final cell in cleared) {
        final neighbours = [
          cell,
          Cell(cell.row - 1, cell.col),
          Cell(cell.row + 1, cell.col),
          Cell(cell.row, cell.col - 1),
          Cell(cell.row, cell.col + 1),
        ];
        for (final n in neighbours) {
          if (n.row < 0 || n.row >= rows || n.col < 0 || n.col >= cols) continue;
          if (obstacle[n.row][n.col] > 0) reduce.add(n);
        }
      }
    }
    for (final cell in reduce) {
      obstacle[cell.row][cell.col]--;
      // spread không tính mục tiêu; các loại khác tính tiến trình clearObstacle
      if (type == ObstacleType.spread) {
        _spreadHitThisMove = true; // đã kìm hãm được lan trong lượt này
      } else {
        controller.registerObstacleClear(1);
      }
      add(ShockwaveComponent(
        position: _cellCenter(cell.row, cell.col),
        color: _obstacleColor(type),
        maxRadius: cellSize * 1.1,
        duration: 0.3,
      )..priority = 48);
    }
  }

  Color _obstacleColor(ObstacleType type) {
    switch (type) {
      case ObstacleType.ice:
        return NeonTheme.cyan;
      case ObstacleType.chain:
        return NeonTheme.yellow;
      case ObstacleType.stone:
        return NeonTheme.purple;
      case ObstacleType.spread:
        return const Color(0xFFB05CFF);
      case ObstacleType.none:
        return Colors.white;
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
        g.isLucky = _rnd.nextDouble() < 0.028; // ~2.8% gem may mắn hiếm
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

  /// Versus: áp [n] hàng RÁC — gem rơi từ trên đẩy bàn XUỐNG, mất [n] hàng đáy.
  /// Rác là gem màu ngẫu nhiên (tránh tạo match ngay → không tặng điểm đối thủ).
  /// Dồn cả cột nên KHÔNG sinh match ngang/dọc mới từ phần dịch.
  Future<void> _applyJunk(int n) async {
    _busy = true;
    _shake((n * 4.0).clamp(4.0, 12.0));
    _flash(NeonTheme.magenta, peak: 0.35); // báo "bị tấn công"
    final futures = <Future>[];
    for (int c = 0; c < cols; c++) {
      // 1) xoá n gem ĐÁY
      for (int r = rows - n; r < rows; r++) {
        final g = grid[r][c];
        if (g == null) continue;
        grid[r][c] = null;
        futures.add(_run(
                g,
                ScaleEffect.to(Vector2.zero(),
                    EffectController(duration: 0.16, curve: Curves.easeIn)))
            .then((_) => g.removeFromParent()));
      }
      // 2) đẩy gem còn lại XUỐNG n hàng (từ đáy lên để không ghi đè)
      for (int r = rows - 1 - n; r >= 0; r--) {
        final g = grid[r][c];
        if (g == null) continue;
        grid[r + n][c] = g;
        grid[r][c] = null;
        g.row = r + n;
        futures.add(_run(
            g,
            MoveToEffect(_cellCenter(r + n, c),
                EffectController(duration: 0.26, curve: Curves.easeIn))));
      }
      // 3) thêm n gem RÁC ở các hàng trên, rơi từ trên xuống
      for (int r = 0; r < n; r++) {
        GemColor color;
        var guard = 0;
        do {
          color = _randomColor();
        } while (guard++ < 20 && _wouldMatchAt(r, c, color));
        final g = GemComponent(
          color: color,
          type: GemType.normal,
          row: r,
          col: c,
          position: _cellCenter(r - n, c),
          cellSize: cellSize,
        );
        grid[r][c] = g;
        boardLayer.add(g);
        futures.add(_run(
            g,
            MoveToEffect(_cellCenter(r, c),
                EffectController(duration: 0.30, curve: Curves.bounceOut))));
      }
    }
    await Future.wait(futures);
    await _ensurePlayable();
    _busy = false;
  }

  /// Versus: đóng băng/mở input (trước countdown / sau khi hết giờ). Dùng cờ
  /// `_ended` sẵn có để chặn tap/drag mà không cần kết thúc ván qua checkEnd.
  void setInputFrozen(bool frozen) => _ended = frozen;

  void _finishMove() {
    onMoveResolved?.call(controller.comboCount.value); // versus: gửi rác theo combo
    final result = controller.checkEnd();
    if (result != null) {
      _ended = true;
      _clearHint();
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

  void _spawnBurst(Vector2 position, Color color, {bool big = false}) {
    // Particle nhẹ: không MaskFilter, dùng blend cộng (BlendMode.plus) tạo cảm giác
    // neon rực mà rẻ. Gem thường 9 hạt; gem special (big) 18 hạt + bay xa hơn.
    final count = big ? 18 : 9;
    final sizeMul = big ? 0.16 : 0.11;
    final particle = Particle.generate(
      count: count,
      lifespan: big ? 0.62 : 0.5,
      generator: (i) {
        final angle = _rnd.nextDouble() * math.pi * 2;
        final speed = (big ? 90 : 60) + _rnd.nextDouble() * (big ? 220 : 150);
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
              canvas.drawCircle(Offset.zero, cellSize * sizeMul * t + 1, paint);
            },
          ),
        );
      },
    );
    add(ParticleSystemComponent(particle: particle, position: position)..priority = 40);
  }

  /// Xử lý chạm bàn khi đang kích hoạt booster.
  void _handleBoosterTap(Cell cell) {
    switch (boosterMode) {
      case BoosterMode.none:
        return;
      case BoosterMode.hammer:
        boosterMode = BoosterMode.none;
        onBoosterUsed?.call(BoosterMode.hammer);
        _smashCells({cell}, color: neonColorOf(grid[cell.row][cell.col]!.color));
        break;
      case BoosterMode.bomb:
        boosterMode = BoosterMode.none;
        onBoosterUsed?.call(BoosterMode.bomb);
        final area = <Cell>{};
        _addArea(area, cell, 1); // 3x3
        add(ShockwaveComponent(
          position: _cellCenter(cell.row, cell.col),
          color: NeonTheme.orange,
          maxRadius: cellSize * 2.4,
        )..priority = 50);
        _flash(NeonTheme.orange, peak: 0.2);
        _smashCells(area, color: NeonTheme.orange);
        break;
      case BoosterMode.colorBlast:
        boosterMode = BoosterMode.none;
        onBoosterUsed?.call(BoosterMode.colorBlast);
        final col = grid[cell.row][cell.col]!.color;
        final cells = <Cell>{};
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            if (grid[r][c]?.color == col) cells.add(Cell(r, c));
          }
        }
        _flash(neonColorOf(col), peak: 0.35);
        _smashCells(cells, color: neonColorOf(col));
        break;
      case BoosterMode.joker:
        boosterMode = BoosterMode.none;
        onBoosterUsed?.call(BoosterMode.joker);
        final g = grid[cell.row][cell.col];
        if (g != null) {
          g.type = GemType.rainbow; // biến thành gem vạn năng (Rainbow)
          add(ShockwaveComponent(
            position: _cellCenter(cell.row, cell.col),
            color: Colors.white,
            maxRadius: cellSize * 1.6,
          )..priority = 55);
          _flash(Colors.white, peak: 0.25);
        }
        break;
      case BoosterMode.swap:
        if (_swapA == null) {
          _swapA = cell;
          grid[cell.row][cell.col]?.selected = true;
        } else {
          final a = grid[_swapA!.row][_swapA!.col];
          final b = grid[cell.row][cell.col];
          a?.selected = false;
          boosterMode = BoosterMode.none;
          _swapA = null;
          if (a != null && b != null && a != b) {
            onBoosterUsed?.call(BoosterMode.swap);
            _forceSwap(a, b);
          }
        }
        break;
    }
  }

  /// Phá 1 tập ô (booster búa/bom/color) — không tốn lượt.
  Future<void> _smashCells(Set<Cell> cells, {required Color color}) async {
    if (_busy || _ended || cells.isEmpty) return;
    _busy = true;
    try {
      final expanded = _expandSpecials(cells);
      _shake((expanded.length * 0.5).clamp(4.0, 12.0));
      await _clearCells(expanded);
      controller.addScore(expanded.length, 1);
      await _applyGravityAndRefill();
      await _settle();
      await _ensurePlayable();
    } finally {
      _busy = false;
      _finishMove();
    }
  }

  /// Booster Swap: hoán đổi 2 gem bất kỳ (không cần kề, không cần tạo match).
  Future<void> _forceSwap(GemComponent a, GemComponent b) async {
    if (_busy || _ended) return;
    _busy = true;
    try {
      await _animateSwap(a, b);
      _swapInGrid(a, b);
      await _settle();
      await _ensurePlayable();
    } finally {
      _busy = false;
      _finishMove();
    }
  }

  // ===== Booster độc quyền (tức thì) =====

  /// Chain Lightning: sét phá tối đa 7 gem cùng màu phổ biến nhất.
  Future<void> chainLightning() async {
    if (_busy || _ended) return;
    final counts = <GemColor, int>{};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final g = grid[r][c];
        if (g != null) counts[g.color] = (counts[g.color] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return;
    final color =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final all = <Cell>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c]?.color == color) all.add(Cell(r, c));
      }
    }
    all.shuffle(_rnd);
    final pick = all.take(7).toList();
    // tia sét nối các gem
    for (int i = 0; i < pick.length - 1; i++) {
      _addBeam(_cellCenter(pick[i].row, pick[i].col),
          _cellCenter(pick[i + 1].row, pick[i + 1].col), neonColorOf(color));
    }
    _flash(neonColorOf(color), peak: 0.25);
    await _smashCells(pick.toSet(), color: neonColorOf(color));
  }

  /// Royal Flush: nổ toàn bộ bàn.
  Future<void> royalFlush() async {
    if (_busy || _ended) return;
    final all = <Cell>{};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] != null) all.add(Cell(r, c));
      }
    }
    _flash(Colors.white, peak: 0.5);
    _shake(14);
    await _smashCells(all, color: Colors.white);
  }

  /// Gravity Flip: đảo trọng lực (đảo thứ tự gem trong mỗi cột) rồi resolve.
  /// Đảo cột (trên↔dưới) + hiệu ứng + settle. KHÔNG quản _busy/_finishMove để
  /// dùng chung được cả booster lẫn chế độ Trọng lực động (gọi trong lượt).
  Future<void> _doColumnFlip() async {
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows ~/ 2; r++) {
        final a = grid[r][c];
        final b = grid[rows - 1 - r][c];
        if (a == null || b == null) continue;
        final tColor = a.color, tType = a.type;
        a.color = b.color;
        a.type = b.type;
        b.color = tColor;
        b.type = tType;
        a.scale = Vector2.all(0.6);
        b.scale = Vector2.all(0.6);
        a.add(ScaleEffect.to(Vector2.all(1),
            EffectController(duration: 0.25, curve: Curves.easeOutBack)));
        b.add(ScaleEffect.to(Vector2.all(1),
            EffectController(duration: 0.25, curve: Curves.easeOutBack)));
      }
    }
    _flash(NeonTheme.cyan, peak: 0.2);
    _shake(8);
    await Future.delayed(const Duration(milliseconds: 280));
    await _settle();
    await _ensurePlayable();
  }

  Future<void> gravityFlip() async {
    if (_busy || _ended) return;
    _busy = true;
    try {
      await _doColumnFlip();
    } finally {
      _busy = false;
      _finishMove();
    }
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
        final cell = cells[i];
        final excluded = (grid[cell.row][cell.col]?.isIngredient ?? false) ||
            (obstacle[cell.row][cell.col] > 0 &&
                (_obstacleType == ObstacleType.stone ||
                    _obstacleType == ObstacleType.spread));
        test[cell.row][cell.col] = excluded ? null : colors[i];
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
      _triggerSlowmo(0.45); // slow-mo kịch tính cho wombo
      HapticFeedback.heavyImpact();
    } else if (combo >= 4) {
      _flash(color, peak: 0.18);
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Time Attack: hiện "+Ns" bay lên (phần thưởng thời gian combo lớn).
  void _spawnTimeBonus(int seconds) {
    add(ComboTextComponent(
      text: '+${seconds}s',
      color: NeonTheme.lime,
      position: Vector2(size.x / 2, size.y * 0.26),
      fontSize: 30,
      maxWidth: size.x * 0.7,
      duration: 0.9,
    )..priority = 71);
  }

  /// Chớp sáng toàn màn (rainbow / combo lớn).
  void _flash(Color color, {double peak = 0.3}) {
    add(FlashOverlay(area: size, color: color, peak: peak)..priority = 80);
  }
}
