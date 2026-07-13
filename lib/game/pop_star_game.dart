import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/audio_manager.dart';
import '../core/neon_theme.dart';
import '../data/levels.dart';
import '../logic/chain_tile.dart';
import '../logic/obstacle.dart';
import '../logic/pop_detector.dart';
import '../logic/power_tile.dart';
import '../presentation/controllers/game_controller.dart';
import 'block_component.dart';

/// G7: viền neon chạy quanh biên nhóm đang preview (G1). Biên = cạnh ngoài
/// (cạnh mà ô kề không thuộc nhóm) của tập ô — vẽ dạng đoạn thẳng riêng lẻ với
/// alpha "sweep" chạy theo thời gian thay vì nối path (đơn giản, vẫn 60fps).
class _EdgeTraceComponent extends PositionComponent {
  _EdgeTraceComponent({required this.color}) : super(priority: 110);

  final Color color;
  List<List<Offset>> segments = const [];
  double _phase = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (segments.isNotEmpty) _phase += dt * 3.2;
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sweep = 0.5 + 0.5 * sin(_phase + i * 0.6);
      canvas.drawLine(
        seg[0],
        seg[1],
        Paint()
          ..color = color.withValues(alpha: 0.45 + 0.5 * sweep)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }
}

/// G8: vòng sáng bung ra từ tâm nhóm vừa nổ rồi mờ dần (shockwave), tự dọn
/// khi xong — game gọi qua [PopStarGame._spawnRing], không tự add() từ ngoài.
class _BurstRing extends PositionComponent {
  _BurstRing({
    required Vector2 center,
    required this.color,
    required this.maxRadius,
    this.maxAlpha = 0.7,
  }) : super(position: center, anchor: Anchor.center, priority: 95);

  final Color color;
  final double maxRadius;
  final double maxAlpha;
  static const double _dur = 0.32;
  double _t = 0;
  VoidCallback? onFinish;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= _dur) {
      onFinish?.call();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / _dur).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero,
      maxRadius * Curves.easeOut.transform(p),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * (1 - p) + 1
        ..color = color.withValues(alpha: (1 - p) * maxAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
}

/// Bàn PopStar: tap 1 ô, nổ nhóm cùng màu liền kề (≥2), cột rơi + dồn trái —
/// có animation (pop nở + hạt, rơi/trượt bằng tween). Không dùng Flame
/// TapDetector — tap đến từ GestureDetector ở game_screen.dart qua [handleTap].
class PopStarGame extends FlameGame {
  PopStarGame(this.controller, {this.refillEnabled = false});

  final GameController controller;

  /// F8 Zen: ngoại lệ luật "không refill" — bàn hết/kẹt thì dựng lại bàn mới
  /// thay vì kết thúc ván. Chỉ bật cho Zen, campaign/Time-attack giữ nguyên
  /// luật gốc.
  final bool refillEnabled;

  late int rows;
  late int cols;
  late double cellSize;
  double _boardLeft = 0;
  double _boardTop = 0;

  /// Nguồn sự thật cho logic (màu từng ô). Đồng bộ với [_blocks] sau mỗi bước.
  late List<List<int?>> colorGrid;

  /// I2: số lần khoá còn lại từng ô (0 = không khoá) — song song [colorGrid],
  /// không tái dùng encoding âm của obstacle vì ô khoá vẫn giữ màu dương thật.
  late List<List<int>> lockGrid;

  /// Component tương ứng từng ô (null nếu trống) — để animate di chuyển.
  late List<List<BlockComponent?>> _blocks;

  /// G7: viền neon chạy quanh biên nhóm đang preview.
  late final _EdgeTraceComponent _edgeTrace;

  /// G8: ring đang bung, cap số lượng đồng thời để nhẹ khi nổ combo dồn dập.
  final List<_BurstRing> _rings = [];
  static const int _maxRings = 3;

  List<List<int?>>? _undoGrid;
  List<List<int>>? _undoLockGrid;
  final _rng = Random();

  /// Đang diễn hoạt → chặn tap để tránh chồng bước.
  bool _animating = false;

  /// Đếm ngược cửa sổ combo; hết → reset combo ở controller.
  double _comboTimer = 0;

  /// I4: rảnh tay quá [_hintDelay] giây → tự gợi ý nhóm lớn nhất còn lại.
  /// [_hint] rỗng nghĩa là chưa/không đang hiển thị gợi ý nào.
  static const double _hintDelay = 6.0;
  double _idleTimer = 0;
  Set<Point<int>> _hint = {};

  static const double _popDur = 0.16;
  static const double _fallDur = 0.26;
  static const double _squashDur = 0.04;

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
    lockGrid = List.generate(rows, (_) => List.generate(cols, (_) => 0));
    _placeObstaclesIfNeeded(level);
    _placeChainLocksIfNeeded(level);
    controller.activeGame = this;
    _layout();
    // ponytail: không await — toImage() có thể không hoàn tất trong widget
    // test (thiếu frame callback thật). render() đã có fallback vẽ blur
    // trực tiếp khi cache chưa sẵn sàng nên khởi kích không đồng bộ là an
    // toàn; cache tự chuyển sang dùng ngay khi bake xong.
    unawaited(BlockComponent.ensureBloomCache());
    _rebuildBoard(animateIntro: true);
    // F6b: dời sang sau frame hiện tại — onLoad() chạy giữa lúc GameWidget
    // đang build, set .obs đồng bộ ở đây gây "setState during build" cho
    // Obx nào đang lắng nghe objectiveRemaining (màn clearColor/clearObstacle).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.updateObjectiveProgress(colorGrid),
    );
    _edgeTrace = _EdgeTraceComponent(color: NeonTheme.cyan);
    add(_edgeTrace);
  }

  /// F6b: màn `clearObstacle` cần vài ô obstacle (giá trị âm = độ bền) rải
  /// ngẫu nhiên trên bàn ngay lúc dựng — số lượng/độ bền tăng nhẹ theo world.
  /// No-op với mọi objective khác (score/clearColor).
  void _placeObstaclesIfNeeded(PopLevel level) {
    if (level.objective.type != ObjectiveType.clearObstacle) return;
    final world = (level.id - 1) ~/ 20;
    final count = (3 + world ~/ 2).clamp(3, 8);
    final durability = 1 + world ~/ 4;
    final cells = <int>{};
    while (cells.length < count && cells.length < rows * cols) {
      cells.add(_rng.nextInt(rows * cols));
    }
    for (final idx in cells) {
      colorGrid[idx ~/ cols][idx % cols] = -durability;
    }
  }

  /// I2: vài ô "bị xích" rải ngẫu nhiên, độc lập với objective (board-gen
  /// spice, không phải điều kiện thắng) — bật theo `level.id % 6 == 0` (tách
  /// khỏi chu kỳ 5-slot objective ở trên), số lượng/lock tăng nhẹ theo world
  /// giống cách [_placeObstaclesIfNeeded] đã làm. Chỉ chọn trong ô màu thật
  /// nên tự bỏ qua ô đã là obstacle nếu 2 điều kiện trùng level.
  void _placeChainLocksIfNeeded(PopLevel level) {
    if (level.id % 6 != 0) return;
    final world = (level.id - 1) ~/ 20;
    final count = (2 + world ~/ 3).clamp(2, 6);
    final lockValue = 1 + world ~/ 5;
    final candidates = [
      for (var idx = 0; idx < rows * cols; idx++)
        if ((colorGrid[idx ~/ cols][idx % cols] ?? -1) >= 0) idx,
    ]..shuffle(_rng);
    for (final idx in candidates.take(count)) {
      lockGrid[idx ~/ cols][idx % cols] = lockValue;
    }
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
    _spawnRipple(pos);
    final power = _blocks[cell.x][cell.y]?.powerKind;
    if (power != null) {
      _activatePowerTile(cell.x, cell.y, power);
    } else {
      _tryPop(cell.x, cell.y);
    }
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
        : findConnectedGroup(colorGrid, cell.x, cell.y, lockGrid: lockGrid);
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
    _updateEdgeTrace();
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
    _edgeTrace.segments = const [];
  }

  void _setHighlight(bool on) {
    for (final p in _preview) {
      _blocks[p.x][p.y]?.highlighted = on;
    }
  }

  /// Cạnh ngoài (ô kề không thuộc nhóm) của [_preview] → đoạn thẳng cho
  /// [_edgeTrace] vẽ viền chạy quanh biên nhóm.
  void _updateEdgeTrace() {
    final segs = <List<Offset>>[];
    for (final p in _preview) {
      final r = p.x, c = p.y;
      final x0 = _boardLeft + c * cellSize;
      final y0 = _boardTop + r * cellSize;
      final x1 = x0 + cellSize;
      final y1 = y0 + cellSize;
      if (!_preview.contains(Point(r - 1, c))) {
        segs.add([Offset(x0, y0), Offset(x1, y0)]);
      }
      if (!_preview.contains(Point(r + 1, c))) {
        segs.add([Offset(x0, y1), Offset(x1, y1)]);
      }
      if (!_preview.contains(Point(r, c - 1))) {
        segs.add([Offset(x0, y0), Offset(x0, y1)]);
      }
      if (!_preview.contains(Point(r, c + 1))) {
        segs.add([Offset(x1, y0), Offset(x1, y1)]);
      }
    }
    _edgeTrace.segments = segs;
  }

  /// Ngưỡng "nổ to" cho flash toàn màn (G2): nhóm lớn hoặc combo cao.
  static const int _bigGroupThreshold = 6;
  static const double _bigComboThreshold = 2.5;

  /// A7: ngưỡng "nổ cực lớn" — hiếm hơn flash G2 — để khựng nhịp ngắn
  /// (slow-mo) + các ô còn sống phóng nhẹ rồi trả về (punch). Cooldown
  /// tránh lặp liên tục khi combo dồn dập.
  static const int _punchGroupThreshold = 8;
  static const double _punchComboThreshold = 3.0;
  static const double _punchCooldownDur = 1.0;
  static const double _slowMoDur = 0.15;
  static const double _slowMoTimeScale = 0.35;
  double _slowMoTimer = 0;
  double _punchCooldownTimer = 0;

  void _tryPop(int row, int col) {
    final group = findConnectedGroup(colorGrid, row, col, lockGrid: lockGrid);
    if (group.length < 2) return;
    _hapticForGroupSize(group.length);
    AudioManager.maybe?.playMelodic(
      combo: group.length,
      colorIndex: colorGrid[row][col] ?? -1,
    );
    _saveUndo();
    final gained = controller.registerPop(scoreForGroup(group.length));
    _comboTimer = GameController.comboWindow;
    _spawnScorePopup(row, col, gained, controller.comboMultiplier.value);
    if (group.length >= _bigGroupThreshold ||
        controller.comboMultiplier.value >= _bigComboThreshold) {
      controller.triggerFlash();
    }
    // F5a: nhóm đủ lớn → ô vừa tap hoá power tile (giữ lại), phần còn lại nổ.
    final kind = powerTileKindForGroupSize(group.length, _rng);
    final cleared = kind != null
        ? (Set<Point<int>>.from(group)..remove(Point(row, col)))
        : group;
    // F6a: nổ nhóm liền kề obstacle → chip độ bền; vỡ thì gộp vào cùng đợt xoá.
    final broken = chipAdjacentObstacles(colorGrid, cleared);
    // I2: nổ nhóm liền kề chain tile → chip 1 lock, không gộp vào tập xoá.
    chipAdjacentLocks(lockGrid, cleared);
    _syncObstacleAndLockBlocks();
    _clearAndCollapse(cleared..addAll(broken));
    if (kind != null) _blocks[row][col]?.powerKind = kind;
  }

  /// I11: rung xúc giác theo cỡ nhóm vừa nổ.
  void _hapticForGroupSize(int size) {
    if (size >= 8) {
      HapticFeedback.heavyImpact();
    } else if (size >= 4) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// F6a/I2: đồng bộ `colorIndex` (obstacle bị chip) và `lockCount` (chain
  /// tile bị chip/mở khoá) sau khi `colorGrid`/`lockGrid` đổi — component
  /// không tự biết giá trị grid đã đổi. Gộp 1 vòng lặp toàn bàn thay vì 2
  /// vòng riêng (board nhỏ nên rẻ, nhưng không cần quét 2 lần).
  void _syncObstacleAndLockBlocks() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final v = colorGrid[r][c];
        if (v != null && v < 0) _blocks[r][c]?.colorIndex = v;
        _blocks[r][c]?.lockCount = lockGrid[r][c];
      }
    }
  }

  /// F5: kích hoạt power tile tại (row, col) — xoá cả hàng/cột (line), vùng
  /// 5x5 quanh tâm (bomb), hoặc toàn bộ ô cùng màu trên bàn (rainbow).
  void _activatePowerTile(int row, int col, PowerTileKind kind) {
    _saveUndo();
    final cells = <Point<int>>{};
    // F6a: obstacle không thuộc nhóm màu → power tile cũng không quét trúng nó
    // (chỉ mòn dần qua chipAdjacentObstacles như match thường).
    switch (kind) {
      case PowerTileKind.lineRow:
        for (var c = 0; c < cols; c++) {
          if ((colorGrid[row][c] ?? -1) >= 0 && lockGrid[row][c] == 0) {
            cells.add(Point(row, c));
          }
        }
      case PowerTileKind.lineCol:
        for (var r = 0; r < rows; r++) {
          if ((colorGrid[r][col] ?? -1) >= 0 && lockGrid[r][col] == 0) {
            cells.add(Point(r, col));
          }
        }
      case PowerTileKind.bomb:
        for (var r = row - 2; r <= row + 2; r++) {
          if (r < 0 || r >= rows) continue;
          for (var c = col - 2; c <= col + 2; c++) {
            if (c < 0 || c >= cols) continue;
            if ((colorGrid[r][c] ?? -1) >= 0 && lockGrid[r][c] == 0) {
              cells.add(Point(r, c));
            }
          }
        }
      case PowerTileKind.rainbow:
        final targetColor = colorGrid[row][col];
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            if (colorGrid[r][c] == targetColor && lockGrid[r][c] == 0) {
              cells.add(Point(r, c));
            }
          }
        }
    }
    if (cells.isEmpty) return;
    final gained = controller.registerPop(scoreForGroup(cells.length));
    _comboTimer = GameController.comboWindow;
    _spawnScorePopup(row, col, gained, controller.comboMultiplier.value);
    if (cells.length >= _bigGroupThreshold ||
        controller.comboMultiplier.value >= _bigComboThreshold) {
      controller.triggerFlash();
    }
    final broken = chipAdjacentObstacles(colorGrid, cells);
    chipAdjacentLocks(lockGrid, cells);
    _syncObstacleAndLockBlocks();
    _clearAndCollapse(cells..addAll(broken));
  }

  /// G6: combo càng cao → bàn "nóng" dần (0..1), block đọc trực tiếp qua [game]
  /// ref thay vì set state từng ô mỗi frame.
  double get heat =>
      ((controller.comboMultiplier.value - 1) / (GameController.comboMax - 1))
          .clamp(0.0, 1.0);

  @override
  void update(double dt) {
    // A7: cửa sổ slow-mo đếm bằng thời gian thật (không scale), chỉ dt đưa
    // xuống cây component mới bị hạ tốc — nên chính cửa sổ luôn dài đúng
    // _slowMoDur thay vì tự kéo dài do dt đã bị hạ.
    if (_slowMoTimer > 0) _slowMoTimer -= dt;
    if (_punchCooldownTimer > 0) _punchCooldownTimer -= dt;
    super.update(_slowMoTimer > 0 ? dt * _slowMoTimeScale : dt);
    if (controller.comboCount.value > 0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0) controller.resetCombo();
    }
    // I4: chỉ đếm giờ rảnh tay khi không diễn hoạt/kết thúc và chưa đang
    // hiển thị gợi ý (đứng yên chờ tap để clear, không tự tắt).
    if (!_animating && !controller.ended.value && _hint.isEmpty) {
      _idleTimer += dt;
      if (_idleTimer >= _hintDelay) _triggerHint();
    }
  }

  /// I4: nhóm đang được gợi ý (rỗng nếu không có). Test-only introspection.
  Set<Point<int>> get hintGroup => _hint;

  /// I4: quét toàn bàn (không phải mỗi frame — chỉ khi hết giờ rảnh tay) tìm
  /// nhóm lớn nhất, tái dùng [findLargestGroup] từ pop_detector.dart.
  void _triggerHint() {
    final group = findLargestGroup(colorGrid, lockGrid: lockGrid);
    if (group.isEmpty) {
      _idleTimer = 0; // bàn kẹt tạm thời — thử lại sau đợt idle kế tiếp
      return;
    }
    _hint = group;
    for (final p in group) {
      _blocks[p.x][p.y]?.hinted = true;
    }
  }

  /// I4: tắt gợi ý đang hiển thị (nếu có) + reset timer rảnh tay. Gọi ở mọi
  /// tap (kể cả tap không hợp lệ) và khi bàn bị dựng lại (shuffle/undo/resize).
  void clearHint() {
    for (final p in _hint) {
      _blocks[p.x][p.y]?.hinted = false;
    }
    _hint = {};
    _idleTimer = 0;
  }

  void triggerBomb(int row, int col) {
    if (_animating) return;
    _saveUndo();
    final cells = <Point<int>>{};
    for (var r = row - 1; r <= row + 1; r++) {
      for (var c = col - 1; c <= col + 1; c++) {
        // F6a: bom không phá trực tiếp obstacle, chỉ chip qua chipAdjacentObstacles.
        if (r >= 0 &&
            r < rows &&
            c >= 0 &&
            c < cols &&
            (colorGrid[r][c] ?? -1) >= 0 &&
            lockGrid[r][c] == 0) {
          cells.add(Point(r, c));
        }
      }
    }
    if (cells.isEmpty) return;
    HapticFeedback.heavyImpact();
    final broken = chipAdjacentObstacles(colorGrid, cells);
    chipAdjacentLocks(lockGrid, cells);
    _syncObstacleAndLockBlocks();
    _clearAndCollapse(cells..addAll(broken));
  }

  /// F3: xoá mọi ô cùng màu với ô (row, col) trên toàn bàn.
  void triggerRainbow(int row, int col) {
    if (_animating) return;
    final targetColor = colorGrid[row][col];
    // F6a: obstacle không có "màu" thật → không cho kích hoạt rainbow trên nó.
    if (targetColor == null || targetColor < 0) return;
    _saveUndo();
    final cells = <Point<int>>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (colorGrid[r][c] == targetColor && lockGrid[r][c] == 0) {
          cells.add(Point(r, c));
        }
      }
    }
    if (cells.isEmpty) return;
    final broken = chipAdjacentObstacles(colorGrid, cells);
    chipAdjacentLocks(lockGrid, cells);
    _syncObstacleAndLockBlocks();
    _clearAndCollapse(cells..addAll(broken));
  }

  /// Xoá [cells]: animate pop từng ô + hạt, rồi rơi/dồn bằng tween, cuối cùng
  /// đồng bộ colorGrid và kiểm tra kết thúc.
  void _clearAndCollapse(Set<Point<int>> cells) {
    _animating = true;
    _maybeTriggerPunch(cells);
    if (cells.isNotEmpty) {
      final first = cells.first;
      final ringColor = NeonTheme
          .gemColors[colorGrid[first.x][first.y]! % NeonTheme.gemColors.length];
      var minR = rows, maxR = -1, minC = cols, maxC = -1;
      var cx = 0.0, cy = 0.0;
      for (final p in cells) {
        if (p.x < minR) minR = p.x;
        if (p.x > maxR) maxR = p.x;
        if (p.y < minC) minC = p.y;
        if (p.y > maxC) maxC = p.y;
        final v = _cellCenter(p.x, p.y);
        cx += v.x;
        cy += v.y;
      }
      final w = (maxC - minC + 1) * cellSize;
      final h = (maxR - minR + 1) * cellSize;
      final radius = sqrt(w * w + h * h) / 2 + cellSize * 0.2;
      _spawnRing(
        Vector2(cx / cells.length, cy / cells.length),
        ringColor,
        radius,
      );
    }
    // G9: pop nhóm lớn (20+ ô) x 10 particle/ô = spike hẳn số draw call.
    // Giảm particle/ô khi nhóm lớn, giữ tổng toàn cụm quanh ~80.
    final burstCount = cells.length <= 8
        ? 10
        : (80 / cells.length).clamp(3, 10).round();
    for (final p in cells) {
      colorGrid[p.x][p.y] = null;
      final b = _blocks[p.x][p.y];
      _blocks[p.x][p.y] = null;
      if (b != null) {
        _spawnBurst(
          b.position.clone(),
          NeonTheme.gemColors[b.colorIndex % NeonTheme.gemColors.length],
          count: burstCount,
        );
        b.add(
          // A8: co nhẹ "lấy đà" trước khi bung — tổng thời lượng vẫn giữ
          // đúng _popDur (không kéo dài nhịp nổ).
          SequenceEffect([
            ScaleEffect.to(
              Vector2.all(0.85),
              EffectController(duration: _squashDur, curve: Curves.easeOut),
            ),
            ScaleEffect.to(Vector2.all(1.3), EffectController(duration: 0.07)),
            ScaleEffect.to(
              Vector2.zero(),
              EffectController(duration: _popDur - _squashDur - 0.07),
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

  /// A7: nhóm ≥8 hoặc combo ≥x3 → khựng nhịp ngắn (mọi effect/animation
  /// chạy chậm lại qua [update]) + các ô còn sống phóng nhẹ rồi trả về.
  /// Không đụng ô vừa bị xoá — đã có `SequenceEffect` scale riêng cho pop,
  /// cộng thêm effect scale khác vào cùng component sẽ đá nhau. Camera thật
  /// (`camera.viewfinder.zoom`) không dùng được vì board add trực tiếp vào
  /// game, không qua `camera.world`, nên zoom camera sẽ không lộ hình.
  void _maybeTriggerPunch(Set<Point<int>> cells) {
    if (_punchCooldownTimer > 0) return;
    final bigGroup = cells.length >= _punchGroupThreshold;
    final bigCombo = controller.comboMultiplier.value >= _punchComboThreshold;
    if (!bigGroup && !bigCombo) return;
    _slowMoTimer = _slowMoDur;
    _punchCooldownTimer = _punchCooldownDur;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (cells.contains(Point(r, c))) continue;
        final b = _blocks[r][c];
        if (b == null) continue;
        b.add(
          SequenceEffect([
            ScaleEffect.to(
              Vector2.all(1.06),
              EffectController(
                duration: _slowMoDur * 0.4,
                curve: Curves.easeOut,
              ),
            ),
            ScaleEffect.to(
              Vector2.all(1),
              EffectController(
                duration: _slowMoDur * 0.6,
                curve: Curves.easeOut,
              ),
            ),
          ]),
        );
      }
    }
  }

  /// G8: bung 1 ring tại [center], cap [_maxRings] cái cùng lúc (huỷ ring cũ
  /// nhất nếu vượt) để nhẹ khi nổ combo dồn dập.
  void _spawnRing(Vector2 center, Color color, double radius) {
    if (_rings.length >= _maxRings) {
      _rings.removeAt(0).removeFromParent();
    }
    final ring = _BurstRing(center: center, color: color, maxRadius: radius);
    ring.onFinish = () => _rings.remove(ring);
    _rings.add(ring);
    add(ring);
  }

  /// A8: sóng nhẹ tại đúng điểm chạm cho mọi tap hợp lệ (kể cả không tạo
  /// nhóm) — phản hồi chạm, tách khỏi [_rings]/[_maxRings] vì tự dọn nhanh
  /// (0.32s), không cần cap khi tap dồn dập.
  void _spawnRipple(Vector2 pos) {
    add(
      _BurstRing(
        center: pos,
        color: Colors.white,
        maxRadius: cellSize * 0.9,
        maxAlpha: 0.35,
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
        lockGrid[r][c] = b?.lockCount ?? 0;
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

  /// Hạt nổ + vệt sáng (G2): tự tính vị trí theo gia tốc để vẽ trail mờ dần
  /// dọc hướng bay (rẻ hơn nhiều so với ghép AcceleratedParticle + sprite).
  void _spawnBurst(Vector2 at, Color color, {int count = 10}) {
    const lifespan = 0.5;
    final accel = Vector2(0, 220);
    add(
      ParticleSystemComponent(
        position: at,
        particle: Particle.generate(
          count: count,
          generator: (i) {
            final a = _rng.nextDouble() * pi * 2;
            final speed = 60 + _rng.nextDouble() * 90;
            final vel = Vector2(cos(a), sin(a)) * speed;
            return ComputedParticle(
              lifespan: lifespan,
              renderer: (canvas, particle) {
                final t = particle.progress * lifespan;
                final pos = vel * t + accel * (0.5 * t * t);
                final curVel = vel + accel * t;
                final dir = curVel.length2 > 0
                    ? curVel.normalized()
                    : Vector2(0, 1);
                final alpha = (1 - particle.progress).clamp(0.0, 1.0);
                final trailLen = cellSize * 0.22;
                canvas.drawLine(
                  Offset(pos.x, pos.y),
                  Offset(pos.x - dir.x * trailLen, pos.y - dir.y * trailLen),
                  Paint()
                    ..color = color.withValues(alpha: alpha * 0.55)
                    ..strokeWidth = cellSize * 0.05
                    ..strokeCap = StrokeCap.round,
                );
                canvas.drawCircle(
                  Offset(pos.x, pos.y),
                  cellSize * 0.08 * alpha.clamp(0.3, 1.0),
                  Paint()..color = color.withValues(alpha: alpha * 0.9),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void shuffleBoard() {
    if (_animating) return;
    _saveUndo();
    // F6a: obstacle không phải màu → giữ nguyên vị trí/độ bền, chỉ xáo màu thật.
    // I2: ô đang khoá cũng giữ nguyên (không xáo màu vào/ra chain tile).
    final values = [
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++)
          if ((colorGrid[r][c] ?? -1) >= 0 && lockGrid[r][c] == 0)
            colorGrid[r][c]!,
    ];
    values.shuffle(_rng);
    var i = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final v = colorGrid[r][c];
        if (v != null && v >= 0 && lockGrid[r][c] == 0) {
          colorGrid[r][c] = values[i++];
        }
      }
    }
    _rebuildBoard();
    _checkEnd();
  }

  bool undo() {
    if (_animating) return false;
    final saved = _undoGrid;
    final savedLocks = _undoLockGrid;
    if (saved == null) return false;
    colorGrid = saved;
    if (savedLocks != null) lockGrid = savedLocks;
    _undoGrid = null;
    _undoLockGrid = null;
    _rebuildBoard();
    return true;
  }

  void _saveUndo() {
    _undoGrid = colorGrid.map((row) => List<int?>.from(row)).toList();
    _undoLockGrid = lockGrid.map((row) => List<int>.from(row)).toList();
  }

  void _checkEnd() {
    final remaining = colorGrid
        .expand((row) => row)
        .where((v) => v != null)
        .length;
    // F5a: còn power tile trên bàn thì vẫn còn nước đi (kích hoạt được), dù
    // không còn nhóm cùng màu ≥2 nào để nổ.
    final hasPowerTile = _blocks
        .expand((row) => row)
        .any((b) => b?.powerKind != null);
    final stuck =
        remaining > 0 &&
        !hasAnyMovableGroup(colorGrid, lockGrid: lockGrid) &&
        !hasPowerTile;
    if (refillEnabled && (remaining == 0 || stuck)) {
      _refillBoard();
      return;
    }
    controller.updateObjectiveProgress(colorGrid);
    // F6b: màn có mục tiêu ngoài điểm → thắng ngay khi dọn xong, không cần
    // đợi bàn hết/kẹt như luật score mặc định.
    if (controller.objectiveMet) {
      controller.checkEnd(remaining == 0);
      return;
    }
    if (remaining == 0) {
      controller.addScore(clearBoardBonus);
      controller.checkEnd(true);
    } else if (stuck) {
      controller.checkEnd(false);
    }
  }

  /// F8 Zen: bàn mới toàn bộ khi hết/kẹt — xem [refillEnabled]. I2: chain
  /// tile chỉ dành cho campaign, bàn Zen mới luôn không khoá ô nào.
  void _refillBoard() {
    final level = controller.currentLevel;
    colorGrid = List.generate(
      rows,
      (_) => List.generate(cols, (_) => _rng.nextInt(level.colorCount)),
    );
    lockGrid = List.generate(rows, (_) => List.generate(cols, (_) => 0));
    _rebuildBoard();
  }

  static const double _introFallDur = 0.35;
  static const double _introStagger = 0.02;

  /// A6: dựng lại toàn bộ bàn. [animateIntro] (đầu màn/retry) → ô rơi so le từ
  /// trên xuống rồi settle nảy nhẹ, khoá tap tới khi xong; các lần dựng lại
  /// khác (resize/shuffle/undo/refill) giữ nguyên tức thì.
  void _rebuildBoard({bool animateIntro = false}) {
    clearHint(); // I4: block cũ sắp bị huỷ, tránh giữ ref rác trong _hint.
    children.whereType<BlockComponent>().toList().forEach(remove);
    _blocks = List.generate(
      rows,
      (_) => List<BlockComponent?>.filled(cols, null),
    );
    if (animateIntro) _animating = true;
    var maxDelay = 0.0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final color = colorGrid[r][c];
        if (color == null) continue;
        final target = _cellCenter(r, c);
        final b = BlockComponent(
          colorIndex: color,
          lockCount: lockGrid[r][c],
          position: animateIntro
              ? Vector2(target.x, _boardTop - cellSize * (r + 2))
              : target,
          size: Vector2.all(cellSize),
        );
        _blocks[r][c] = b;
        add(b);
        if (animateIntro) {
          final delay = (r + c) * _introStagger;
          if (delay > maxDelay) maxDelay = delay;
          b.add(
            MoveToEffect(
              target,
              EffectController(
                duration: _introFallDur,
                startDelay: delay,
                curve: Curves.easeOutBack,
              ),
            ),
          );
        }
      }
    }
    if (animateIntro) {
      add(
        TimerComponent(
          period: maxDelay + _introFallDur,
          removeOnFinish: true,
          onTick: () => _animating = false,
        ),
      );
    }
  }
}
