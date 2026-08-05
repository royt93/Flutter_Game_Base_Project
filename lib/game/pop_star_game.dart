import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/audio_manager.dart';
import '../core/debug_log.dart';
import '../core/haptics.dart';
import '../core/neon_theme.dart';
import '../data/burst_styles.dart';
import '../data/combo_milestones.dart';
import '../data/levels.dart';
import '../data/mirror_board.dart';
import '../logic/boss_tile.dart';
import '../logic/chain_tile.dart';
import '../logic/countdown_lock_tile.dart';
import '../logic/gift_tile.dart';
import '../logic/magnet_tile.dart';
import '../logic/obstacle.dart';
import '../logic/pop_collapse.dart';
import '../logic/pop_detector.dart';
import '../logic/power_tile.dart';
import '../logic/time_freeze_tile.dart';
import '../logic/wildcard_tile.dart';
import '../core/storage_service.dart';
import '../presentation/controllers/boss_rush_controller.dart';
import '../presentation/controllers/game_controller.dart';
import '../presentation/controllers/game_screen_controller.dart';
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
  PopStarGame(
    this.controller, {
    this.refillEnabled = false,
    this.startWithFtueHint = false,
    this.presetGrid,
    int? seed,
    this.recordingEnabled = false,
    this.isReplay = false,
  }) : seed = seed ?? Random().nextInt(1 << 31);

  final GameController controller;

  /// I28: đang chạy ở `GhostReplayScreen` (auto-playback mã chia sẻ) — chặn
  /// mọi call site persist thưởng/tiến trình thật (coin/sao/highScore/unlock)
  /// qua [controller], vì [controller] ở màn replay là 1 instance dùng 1 lần
  /// (không phải singleton) nhưng các method của nó vẫn ghi thẳng vào
  /// `StorageService.to` singleton — nếu không chặn, replay của bất kỳ ai
  /// cũng có thể "cày" điểm/coin/mở khoá level thật cho người xem.
  final bool isReplay;

  /// I28: [isReplay] tự phát hiện ván đã kết thúc (dọn sạch hoặc kẹt) — thay
  /// cho `controller.checkEnd` bị chặn ở trên. `GhostReplayScreen` đọc field
  /// này để biết khi nào dừng auto-playback + hiện thông báo hoàn tất.
  bool replayEnded = false;

  /// I28: seed dùng cho [_rng] — cố định để bàn/ngẫu nhiên tái tạo được y hệt
  /// qua `PopStarGame(seed: seed)`. Không truyền → tự sinh ngẫu nhiên (không
  /// đổi UX chơi thường), nhưng seed đã dùng luôn được giữ lại qua field này
  /// để chia sẻ replay sau khi ván kết thúc.
  final int seed;

  /// I28: bật ghi lại thứ tự tap để tạo mã chia sẻ ghost-replay. Mặc định tắt
  /// để không tốn bộ nhớ mỗi ván chơi bình thường.
  final bool recordingEnabled;

  /// I28: thứ tự (row, col) đã tap qua [handleTap] — chỉ ghi khi
  /// [recordingEnabled] và [recordingValid]. Danh sách rỗng nếu chưa tap.
  final List<(int, int)> recordedTaps = [];

  /// I28: false nếu ván đã dùng hành động không tái tạo được từ tap thuần
  /// (bomb/rainbow/swap/shuffle/undo/freeze) — replay lúc này sẽ không khớp
  /// nếu chỉ replay lại [recordedTaps], nên không cho chia sẻ.
  bool recordingValid = true;

  /// F13: bàn cố định (Daily Challenge) thay vì random — set qua
  /// [GameController.dailyChallengeGrid]. Null nghĩa là sinh random như bình
  /// thường.
  final List<List<int>>? presetGrid;

  /// F8 Zen: ngoại lệ luật "không refill" — bàn hết/kẹt thì dựng lại bàn mới
  /// thay vì kết thúc ván. Chỉ bật cho Zen, campaign/Time-attack giữ nguyên
  /// luật gốc.
  final bool refillEnabled;

  /// X1: FTUE — level 1 lần đầu ép hiện gợi ý ngay khi board sẵn sàng, không
  /// chờ đủ [_hintDelay] giây rảnh tay như I4 bình thường. Đọc trong
  /// [onLoad] (không thể trigger ngay sau constructor vì [colorGrid] chỉ
  /// init xong trong onLoad()).
  final bool startWithFtueHint;

  /// I52: kiểu hiệu ứng nổ đang chọn — đọc 1 lần trong [onLoad] từ
  /// `controller.activeBurstStyleKind` (đã được [GameController._load]
  /// re-validate ngưỡng unlock, KHÔNG tự parse `StorageKeys.activeBurstStyle`
  /// trực tiếp — tránh lệch dữ liệu nếu storage bị sửa tay để trỏ style chưa
  /// mở khoá, xem tương tự cách [GameController.setActiveBurstStyle] chặn).
  late final BurstStyleKind _activeBurstKind;

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

  /// spark/confetti/starburst đang bung, cap số lượng đồng thời (cùng lý do
  /// [_rings]/[_maxRings]) để tránh combo dồn dập chồng quá nhiều particle
  /// system cùng lúc.
  final List<ParticleSystemComponent> _bursts = [];
  static const int _maxBursts = 6;

  List<List<int?>>? _undoGrid;
  List<List<int>>? _undoLockGrid;

  /// Snapshot điểm/combo tại thời điểm [_saveUndo] — thiếu phần này thì undo
  /// chỉ hoàn tác bàn cờ mà giữ nguyên điểm vừa cộng, cho phép farm điểm vô
  /// hạn (pop → undo giữ điểm → pop lại đúng nhóm đó → undo...).
  int? _undoScore;
  int? _undoComboCount;
  double? _undoComboMultiplier;
  int? _undoMovesUsed;

  /// I29: HP hiện tại từng boss tile trên bàn (id → HP), ngoài [colorGrid] —
  /// xem `lib/logic/boss_tile.dart`. Rỗng nếu màn không có boss tile.
  final Map<int, int> bossHp = {};
  Map<int, int>? _undoBossHp;

  /// I45: số lượt tap còn lại từng Countdown Lock trên bàn (id → còn bấy
  /// nhiêu lượt) — mirror cấu trúc [bossHp] nhưng giảm theo lượt tap, không
  /// theo pop-kề-cạnh. Rỗng nếu màn không có Countdown Lock.
  final Map<int, int> countdownRemaining = {};
  Map<int, int>? _undoCountdownRemaining;
  late final Random _rng = Random(seed);

  /// F10: > 0 nghĩa freeze đang hiệu lực — obstacle không giảm bền, mỗi lần
  /// đáng lẽ chip (xem [_chipObstaclesOrFrozen]) trừ 1 thay vì chip thật.
  int freezeTurnsLeft = 0;

  /// I28: wrapper cho [freezeTurnsLeft] — dùng bởi `GameController.useFreeze`
  /// thay vì gán field trực tiếp, để cũng invalidate [recordingValid] (freeze
  /// không tái tạo được nếu chỉ replay lại [recordedTaps]).
  void applyFreeze(int turns) {
    recordingValid = false;
    freezeTurnsLeft = turns;
  }

  /// Đang diễn hoạt → chặn tap để tránh chồng bước.
  bool _animating = false;

  /// Codex review: tăng mỗi lần bắt đầu 1 chuỗi animation mới (set
  /// `_animating = true`). TimerComponent hạ `_animating = false` phải chụp
  /// giá trị này lúc lên lịch rồi so lại lúc chạy — nếu lệch nghĩa là một
  /// animation MỚI đã đè lên (vd shuffle tự gọi `_checkEnd()` kích hoạt
  /// `_clearAndCollapse()` do boss-decay-on-stuck) thì bỏ qua, tránh 2 timer
  /// độc lập giành ghi `_animating` khiến khoá bị hạ sớm giữa animation khác.
  int _animGen = 0;

  /// Đếm ngược cửa sổ combo; hết → reset combo ở controller.
  double _comboTimer = 0;

  /// I4: rảnh tay quá [_hintDelay] giây → tự gợi ý nhóm lớn nhất còn lại.
  /// [_hint] rỗng nghĩa là chưa/không đang hiển thị gợi ý nào.
  /// F14: perk `move_hint` active thì rút ngắn còn 1/3 (gợi ý sớm hơn).
  double get _hintDelay => controller.hasPerk('move_hint') ? 2.0 : 6.0;
  double _idleTimer = 0;
  Set<Point<int>> _hint = {};

  /// I31: đếm ngược tự tắt gợi ý bấm-thủ-công (nút Hint) — khác gợi ý
  /// idle-trigger ở trên vốn đứng yên tới khi tap. 0 = không có countdown.
  static const double _manualHintDur = 1.5;
  double _manualHintTimer = 0;

  static const double _popDur = 0.16;
  static const double _fallDur = 0.26;
  static const double _squashDur = 0.04;

  // Nền canvas trong suốt để tray sáng + nền candy phía sau lộ qua (mặc định
  // FlameGame tô đen).
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    _activeBurstKind = controller.activeBurstStyleKind.value;
    final level = controller.currentLevel;
    rows = level.rows;
    cols = level.cols;
    colorGrid = presetGrid != null
        ? presetGrid!.map((row) => List<int?>.of(row)).toList()
        : List.generate(
            rows,
            (_) => List.generate(cols, (_) => _rng.nextInt(level.colorCount)),
          );
    lockGrid = List.generate(rows, (_) => List.generate(cols, (_) => 0));
    _ensureCollectTargetIfNeeded(level);
    // I29: đặt boss tile TRƯỚC obstacle/chain-lock/gift — 3 hàm sau lọc ứng
    // viên bằng `>= 0` nên tự loại trừ cell boss (mã âm), tránh bị ghi đè.
    _placeBossTileIfNeeded(level);
    _placeObstaclesIfNeeded(level);
    _placeChainLocksIfNeeded(level);
    _placeGiftsIfNeeded(level);
    _placeCountdownLockTileIfNeeded(level);
    _placeWildcardTileIfNeeded(level);
    _placeMagnetTileIfNeeded(level);
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
    if (startWithFtueHint) _triggerHint();
    dlog(
      'onLoad done: rows=$rows cols=$cols size=$size cellSize=$cellSize '
      'boardLeft=$_boardLeft boardTop=$_boardTop nonNullCells='
      '${colorGrid.expand((r) => r).where((v) => v != null).length}',
    );
  }

  /// F9-fix: màn `collect` cần đủ SỐ Ô màu mục tiêu ngay từ đầu — bàn random
  /// thuần i.i.d không đảm bảo đủ, khiến objective có thể không thể đạt được
  /// (board không refill). Nếu thiếu, tô lại ngẫu nhiên vài ô KHÔNG PHẢI màu
  /// target (qua `_rng`, giống cách [_placeGiftsIfNeeded] chọn candidate)
  /// sang màu target. Không đụng preset board (guard `presetGrid == null`).
  void _ensureCollectTargetIfNeeded(PopLevel level) {
    if (presetGrid != null) return;
    if (level.objective.type != ObjectiveType.collect) return;
    final targetColor = level.objective.color!;
    final needed = level.objective.target!;
    final current = colorGrid
        .expand((row) => row)
        .where((v) => v == targetColor)
        .length;
    final shortfall = needed - current;
    if (shortfall <= 0) return;
    final candidates = _shuffledCandidates(
      (idx) => colorGrid[idx ~/ cols][idx % cols] != targetColor,
    );
    for (final idx in candidates.take(shortfall)) {
      colorGrid[idx ~/ cols][idx % cols] = targetColor;
    }
  }

  /// Ô này có phải màu target của objective `collect` không — dùng để loại
  /// trừ khỏi mọi ứng viên ghi đè `colorGrid` phía sau (countdown-lock,
  /// wildcard...). Thiếu bước né này thì [_ensureCollectTargetIfNeeded] vừa
  /// tô đủ số ô có thể bị ghi đè ngay sau đó, kéo số đếm xuống dưới target —
  /// `_collectInitial` (chụp ở postFrameCallback, SAU mọi placement pass)
  /// sẽ phản ánh số đã bị giảm, khiến objective collect vĩnh viễn không đạt.
  bool _isCollectTarget(PopLevel level, int idx) {
    if (level.objective.type != ObjectiveType.collect) return false;
    return colorGrid[idx ~/ cols][idx % cols] == level.objective.color;
  }

  /// Idiom dùng chung cho mọi hàm `_place*IfNeeded`: liệt kê index hợp lệ
  /// theo [eligible] rồi xáo bằng `_rng` (giữ seed-determinism cho
  /// replay/challenge-code). Gọi `.take(n)` trên kết quả để lấy candidate.
  List<int> _shuffledCandidates(bool Function(int idx) eligible) {
    return [
      for (var idx = 0; idx < rows * cols; idx++)
        if (eligible(idx)) idx,
    ]..shuffle(_rng);
  }

  /// I29: đặt 1 boss tile (nếu [PopLevel.bossTileSpec] khớp) — mỗi màn chỉ có
  /// tối đa 1 khối nên dùng thẳng [bossTileIdBase] làm id, không cần tăng dần.
  void _placeBossTileIfNeeded(PopLevel level) {
    final spec = level.bossTileSpec;
    if (spec == null) return;
    bossHp[bossTileIdBase] = placeBossTile(colorGrid, spec, bossTileIdBase);
  }

  /// F6b: màn `clearObstacle` cần vài ô obstacle (giá trị âm = độ bền) rải
  /// ngẫu nhiên trên bàn ngay lúc dựng — số lượng/độ bền tăng nhẹ theo world.
  /// F9: `obstacleInMoves` dùng chung cơ chế, số lượng lấy đúng
  /// [LevelObjective.target] để khớp mục tiêu. No-op với objective khác.
  void _placeObstaclesIfNeeded(PopLevel level) {
    final type = level.objective.type;
    if (type != ObjectiveType.clearObstacle &&
        type != ObjectiveType.obstacleInMoves) {
      return;
    }
    final world = (level.id - 1) ~/ 20;
    final count = type == ObjectiveType.obstacleInMoves
        ? level.objective.target!
        : (3 + world ~/ 2).clamp(3, 8);
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
    final candidates = _shuffledCandidates(
      (idx) => (colorGrid[idx ~/ cols][idx % cols] ?? -1) >= 0,
    );
    for (final idx in candidates.take(count)) {
      lockGrid[idx ~/ cols][idx % cols] = lockValue;
    }
  }

  /// I1: chỉ spawn khi objective là `openGift` — số ô quà = đúng target cần
  /// mở. Né ô đã là obstacle/chain-lock, giống cách [_placeChainLocksIfNeeded]
  /// né obstacle.
  void _placeGiftsIfNeeded(PopLevel level) {
    if (level.objective.type != ObjectiveType.openGift) return;
    final count = level.objective.target!;
    final candidates = _shuffledCandidates(
      (idx) =>
          (colorGrid[idx ~/ cols][idx % cols] ?? -1) >= 0 &&
          lockGrid[idx ~/ cols][idx % cols] == 0,
    );
    for (final idx in candidates.take(count)) {
      colorGrid[idx ~/ cols][idx % cols] = giftTileValue;
    }
  }

  /// I45: ~18% cơ hội 1 ô Countdown Lock ở world ≥4 (level > 60), campaign
  /// only — side-mode dùng `level.id` âm/đặc biệt nên tự loại, giống
  /// [_placeObstaclesIfNeeded] không cần check `controller.mode`. Né ô đã là
  /// obstacle/chain-lock/gift/boss, giống [_placeGiftsIfNeeded]. Né thêm ô
  /// màu target của objective `collect` (xem [_isCollectTarget]) — nếu
  /// không, có thể đè lên đúng ô [_ensureCollectTargetIfNeeded] vừa tô thêm
  /// để đủ target, làm objective collect vĩnh viễn không đạt được.
  static const double _countdownLockChance = 0.18;

  void _placeCountdownLockTileIfNeeded(PopLevel level) {
    if (level.id <= 60) return;
    if (_rng.nextDouble() >= _countdownLockChance) return;
    final candidates = _shuffledCandidates(
      (idx) =>
          (colorGrid[idx ~/ cols][idx % cols] ?? -1) >= 0 &&
          lockGrid[idx ~/ cols][idx % cols] == 0 &&
          !_isCollectTarget(level, idx),
    );
    if (candidates.isEmpty) return;
    final idx = candidates.first;
    colorGrid[idx ~/ cols][idx % cols] = countdownLockIdBase;
    countdownRemaining[countdownLockIdBase] = countdownLockStartValue;
  }

  /// I46: ~15% cơ hội 1 ô Wildcard, campaign only (mọi world) — side-mode
  /// dùng `level.id` <= 0 nên tự loại, giống [_placeCountdownLockTileIfNeeded].
  /// Né ô đã là obstacle/chain-lock/gift/boss/countdown-lock, giống
  /// [_placeGiftsIfNeeded] (mọi giá trị đặc biệt đều âm nên check `>= 0` đủ
  /// loại hết). Né thêm ô màu target của objective `collect`, cùng lý do với
  /// [_placeCountdownLockTileIfNeeded]. Không cần state map riêng — wildcard
  /// chỉ là 1 giá trị mã hoá cố định trong `colorGrid`, không có số đếm/HP
  /// đi kèm.
  static const double _wildcardTileChance = 0.15;

  void _placeWildcardTileIfNeeded(PopLevel level) {
    if (level.id <= 0) return;
    if (_rng.nextDouble() >= _wildcardTileChance) return;
    final candidates = _shuffledCandidates(
      (idx) =>
          (colorGrid[idx ~/ cols][idx % cols] ?? -1) >= 0 &&
          lockGrid[idx ~/ cols][idx % cols] == 0 &&
          !_isCollectTarget(level, idx),
    );
    if (candidates.isEmpty) return;
    final idx = candidates.first;
    colorGrid[idx ~/ cols][idx % cols] = wildcardTileValue;
  }

  /// I68: tối đa một Magnet từ world 4 (level > 60), campaign only.
  /// Placement chạy sau các special tile khác và chỉ chọn ô màu chưa khoá,
  /// nên không thể ghi đè obstacle/gift/boss/wildcard/countdown/chain.
  static const double _magnetTileChance = 0.18;

  void _placeMagnetTileIfNeeded(PopLevel level) {
    if (level.id <= 60 || controller.mode.value != GameMode.campaign) return;
    if (_rng.nextDouble() >= _magnetTileChance) return;
    final candidates = _shuffledCandidates(
      (idx) =>
          (colorGrid[idx ~/ cols][idx % cols] ?? -1) >= 0 &&
          lockGrid[idx ~/ cols][idx % cols] == 0 &&
          !_isCollectTarget(level, idx),
    );
    if (candidates.isEmpty) return;
    final idx = candidates.first;
    final targetColor = _rng.nextInt(level.colorCount);
    colorGrid[idx ~/ cols][idx % cols] = encodeMagnetTile(targetColor);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    dlog('onGameResize: size=$size isLoaded=$isLoaded');
    if (isLoaded) {
      _layout();
      _rebuildBoard();
      dlog(
        'onGameResize rebuild done: cellSize=$cellSize blocks='
        '${children.whereType<BlockComponent>().length}',
      );
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

  /// I28: bản public của [_cellCenter] để `GhostReplayScreen` tính toạ độ tap
  /// từ (row, col) đã ghi trong [recordedTaps], phục vụ auto-playback.
  Vector2 cellCenterFor(int row, int col) => _cellCenter(row, col);

  /// I28: cho `GhostReplayScreen` biết khi nào an toàn để tap lượt kế tiếp
  /// (tránh tap trong lúc animation đang chạy, sẽ bị [handleTap] bỏ qua).
  bool get isAnimating => _animating;

  /// I71: nới hit-test [_kEdgeTapTolerance]px ở mép NGOÀI bàn cờ khi bật
  /// Settings > larger tap targets — chỉ kéo tap lệch ra ngoài về lại ô biên
  /// gần nhất, không đổi ô nào được chọn khi tap đã nằm trong bàn (không
  /// snap sang ô lân cận, tránh đổi kết quả gameplay không đoán trước).
  static const double _kEdgeTapTolerance = 12.0;

  /// Ô (row, col) tại [pos] trong không gian game, hoặc null nếu ngoài bàn.
  Point<int>? cellAt(Vector2 pos) {
    final tolerance = controller.largerTapTargets.value
        ? _kEdgeTapTolerance
        : 0.0;
    final boardRight = _boardLeft + cols * cellSize;
    final boardBottom = _boardTop + rows * cellSize;
    if (pos.x < _boardLeft - tolerance || pos.x >= boardRight + tolerance) {
      return null;
    }
    if (pos.y < _boardTop - tolerance || pos.y >= boardBottom + tolerance) {
      return null;
    }
    final col = (((pos.x - _boardLeft) / cellSize).floor()).clamp(0, cols - 1);
    final row = (((pos.y - _boardTop) / cellSize).floor()).clamp(0, rows - 1);
    return Point(row, col);
  }

  /// [pos] toạ độ trong không gian game (đã convert từ local position ở UI).
  void handleTap(Vector2 pos) {
    if (_animating) return;
    final cell = cellAt(pos);
    if (cell == null) return;
    if (recordingEnabled && recordingValid) {
      recordedTaps.add((cell.x, cell.y));
    }
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
          shadows: [
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

  /// A1: nhóm ≥[_shakeGroupThreshold] ô → bàn rung nhẹ (biên độ cap
  /// cellSize*0.12, tắt sau 3 nhịp ~0.12s) — nhẹ hơn/thường xuyên hơn punch A7.
  /// I17-fix: trước đây không có cooldown — combo dồn dập trigger liên tục,
  /// chồng SequenceEffect mới lên cùng block mỗi lần. Thêm cooldown ngắn
  /// giống punch (nhưng ngắn hơn vì shake vốn nhẹ/thường xuyên hơn).
  static const int _shakeGroupThreshold = 5;
  static const double _shakeCooldownDur = 0.3;
  double _shakeCooldownTimer = 0;

  /// I17-fix: punch/shake trước đây duyệt toàn bộ rows×cols (tới 132 ô ở
  /// world 11) mỗi lần trigger — chỉ cần vùng quanh nhóm vừa nổ là đủ cảm
  /// giác "rung/giật", giới hạn phạm vi để giảm số Effect cấp phát.
  static const int _effectRegionMargin = 2;

  /// Bounding box của [cells] mở rộng thêm [_effectRegionMargin], kẹp trong
  /// biên bàn — dùng để giới hạn phạm vi duyệt của punch/shake.
  (int, int, int, int) _effectRegion(Set<Point<int>> cells) {
    var minR = rows, maxR = 0, minC = cols, maxC = 0;
    for (final p in cells) {
      if (p.x < minR) minR = p.x;
      if (p.x > maxR) maxR = p.x;
      if (p.y < minC) minC = p.y;
      if (p.y > maxC) maxC = p.y;
    }
    return (
      (minR - _effectRegionMargin).clamp(0, rows - 1),
      (maxR + _effectRegionMargin).clamp(0, rows - 1),
      (minC - _effectRegionMargin).clamp(0, cols - 1),
      (maxC + _effectRegionMargin).clamp(0, cols - 1),
    );
  }

  /// A7: tắt slow-mo/zoom-punch/shake qua Settings cho người nhạy chuyển
  /// động. Không gate squash/settle (easeOutBack) hay pop cơ bản — chỉ các
  /// hiệu ứng "thêm" ngoài phản hồi tap cốt lõi.
  bool get _reduceMotion => StorageService.to.getBool(StorageKeys.reduceMotion);

  void _tryPop(int row, int col) {
    final group = findConnectedGroup(colorGrid, row, col, lockGrid: lockGrid);
    if (group.length < 2) {
      // I44: ô Time Freeze tap lẻ loi (không cần gộp nhóm ≥2) vẫn kích hoạt
      // +10s rồi biến mất, tái dùng nguyên hiệu ứng nổ/rơi của 1 ô thường.
      if (_blocks[row][col]?.timeFreezeTagged == true) {
        _blocks[row][col]!.timeFreezeTagged = false;
        _triggerTimeFreeze();
        _clearAndCollapse({Point(row, col)});
      }
      return;
    }
    if (!meetsMinGroupSize(group, controller.activeMinGroupSize)) {
      fireHaptic(HapticLevel.light);
      return;
    }
    // I44: ô Time Freeze pop chung trong 1 nhóm màu ≥2 vẫn kích hoạt +10s
    // (tối đa 1 ô được tag/bàn nên chỉ có thể trúng đúng 1 ô trong group).
    for (final p in group) {
      if (_blocks[p.x][p.y]?.timeFreezeTagged == true) {
        _blocks[p.x][p.y]!.timeFreezeTagged = false;
        _triggerTimeFreeze();
      }
    }
    // I45: mỗi lượt tap hợp lệ (nhóm ≥2, bất kể có đụng Countdown Lock hay
    // không) giảm 1 mọi Countdown Lock trên bàn — khác cơ chế chip-theo-kề
    // của obstacle/boss/chain lock.
    _tickCountdownLockTiles();
    _hapticForGroupSize(group.length);
    AudioManager.maybe?.playMelodic(
      combo: group.length,
      colorIndex: colorGrid[row][col] ?? -1,
    );
    _saveUndo();
    // I28: replay chỉ để xem lại — không cộng điểm/combo thật qua controller
    // (xem [isReplay]); dùng điểm thô không nhân combo cho popup hiển thị.
    // I49: campaign pop trúng đúng lucky color của ngày → nhân thêm ×1.2.
    final popColor = colorGrid[row][col] ?? -1;
    // I68: lấy tọa độ trước khi bất kỳ gravity/collapse nào chạy. Magnet
    // không thuộc flood-fill, vì vậy chỉ được cộng đúng bonus thụ động này.
    final triggeredMagnets = magnetTilesTriggeredBy(
      colorGrid,
      popColor,
    ).map((cell) => Point(cell.$1, cell.$2)).toSet();
    final baseScore = scoreForGroup(group.length);
    final isLucky =
        controller.mode.value == GameMode.campaign &&
        popColor == controller.luckyColorIndex.value;
    final adjustedScore =
        (isLucky ? (baseScore * 1.2).round() : baseScore) +
        triggeredMagnets.length * magnetBonusScore;
    final gained = isReplay
        ? adjustedScore
        : controller.registerPop(adjustedScore, groupSize: group.length);
    _comboTimer =
        controller.activeComboWindowOverride ?? GameController.comboWindow;
    final gemColor = NeonTheme
        .gemColors[(colorGrid[row][col] ?? 0) % NeonTheme.gemColors.length];
    _spawnScorePopup(
      row,
      col,
      gained,
      controller.comboMultiplier.value,
      gemColor,
    );
    if (group.length >= _bigGroupThreshold ||
        controller.comboMultiplier.value >= _bigComboThreshold) {
      controller.triggerFlash();
    }
    // I39: mốc combo cố định → text "COMBO x{N}!" + rung mạnh hơn.
    if (isComboMilestone(controller.comboCount.value)) {
      controller.triggerComboMilestone(controller.comboCount.value);
      fireHaptic(hapticForComboMilestone(controller.comboCount.value));
    }
    // F5a: nhóm đủ lớn → ô vừa tap hoá power tile (giữ lại), phần còn lại nổ.
    final kind = powerTileKindForGroupSize(group.length, _rng);
    final cleared = kind != null
        ? (Set<Point<int>>.from(group)..remove(Point(row, col)))
        : group;
    cleared.addAll(triggeredMagnets);
    // F6a: nổ nhóm liền kề obstacle → chip độ bền; vỡ thì gộp vào cùng đợt xoá.
    final broken = _chipObstaclesOrFrozen(cleared);
    // I29: nổ nhóm liền kề boss tile → chip 1 HP; vỡ thì gộp vào cùng đợt xoá.
    final bossBroken = _chipAdjacentBossTiles(cleared);
    // I2: nổ nhóm liền kề chain tile → chip 1 lock, không gộp vào tập xoá.
    chipAdjacentLocks(lockGrid, cleared);
    _syncObstacleAndLockBlocks();
    _clearAndCollapse(
      cleared
        ..addAll(broken)
        ..addAll(bossBroken),
    );
    if (kind != null) _blocks[row][col]?.powerKind = kind;
  }

  /// F10: freeze đang hiệu lực → bỏ qua chip (trừ 1 lượt), ngược lại chip
  /// bình thường qua [chipAdjacentObstacles]. Dùng thay thế tại mọi nơi từng
  /// gọi thẳng [chipAdjacentObstacles] để obstacle "miễn nhiễm" đúng N lượt.
  Set<Point<int>> _chipObstaclesOrFrozen(Set<Point<int>> cells) {
    if (freezeTurnsLeft > 0) {
      freezeTurnsLeft--;
      return {};
    }
    return chipAdjacentObstacles(colorGrid, cells);
  }

  /// I29: nổ nhóm liền kề boss tile → chip 1 HP; HP về 0 thì trả về cell vừa
  /// vỡ để gộp vào tập xoá, giống pattern [_chipObstaclesOrFrozen]. Id nào
  /// giảm HP nhưng CHƯA vỡ được đánh dấu ring nhỏ riêng (VFX "nứt", khác ring
  /// nổ chung của tập vỡ hẳn mà [_clearAndCollapse] đã tự lo).
  Set<Point<int>> _chipAdjacentBossTiles(Set<Point<int>> cells) {
    final before = Map<int, int>.from(bossHp);
    final broken = chipAdjacentBossTiles(colorGrid, cells, bossHp);
    _spawnBossChipRingsForDecrement(before);
    return broken;
  }

  /// So HP trước/sau 1 lần chip/decay — id còn sống nhưng HP giảm (chưa vỡ,
  /// đã bị [_decrementAndBreak] xoá khỏi [bossHp] nếu vỡ) thì phát 1 ring nhỏ
  /// tại từng cell của nó, tái dùng [_spawnRing] như acceptance criteria I29
  /// yêu cầu (không cần loại `_BurstRing`/component mới).
  void _spawnBossChipRingsForDecrement(Map<int, int> before) {
    for (final entry in before.entries) {
      final after = bossHp[entry.key];
      if (after != null && after < entry.value) {
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            if (colorGrid[r][c] == entry.key) {
              _spawnRing(_cellCenter(r, c), NeonTheme.red, cellSize * 0.55);
            }
          }
        }
      }
    }
  }

  /// I45: giảm 1 mọi Countdown Lock trên bàn; hết giờ (0) thì chuyển ô đó
  /// thành obstacle thường (durability 1) — chỉ 1 cell/id vì mỗi màn tối đa
  /// 1 instance (xem [_placeCountdownLockTileIfNeeded]).
  void _tickCountdownLockTiles() {
    if (countdownRemaining.isEmpty) return;
    final expiredId = tickCountdownLockTiles(countdownRemaining);
    if (expiredId == null) return;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (colorGrid[r][c] == expiredId) colorGrid[r][c] = -1;
      }
    }
  }

  /// I11: rung xúc giác theo cỡ nhóm vừa nổ.
  void _hapticForGroupSize(int size) =>
      fireHaptic(hapticLevelForGroupSize(size));

  /// F6a/I2: đồng bộ `colorIndex` (obstacle bị chip) và `lockCount` (chain
  /// tile bị chip/mở khoá) sau khi `colorGrid`/`lockGrid` đổi — component
  /// không tự biết giá trị grid đã đổi. Gộp 1 vòng lặp toàn bàn thay vì 2
  /// vòng riêng (board nhỏ nên rẻ, nhưng không cần quét 2 lần).
  void _syncObstacleAndLockBlocks() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final v = colorGrid[r][c];
        if (v != null && v < 0) _blocks[r][c]?.colorIndex = v;
        // I29: HP không mã hoá trong colorGrid (chỉ mã ID) nên cần đồng bộ
        // riêng từ [bossHp] để BlockComponent hiển thị số HP còn lại.
        if (isBossTileId(v)) _blocks[r][c]?.bossHp = bossHp[v];
        // I45: đếm ngược không mã hoá trong colorGrid (chỉ mã ID) nên cần
        // đồng bộ riêng từ [countdownRemaining], giống pattern bossHp ở trên.
        _blocks[r][c]?.countdownDisplay = isCountdownLockId(v)
            ? countdownRemaining[v]
            : null;
        _blocks[r][c]?.lockCount = lockGrid[r][c];
      }
    }
  }

  /// F5: vùng ô bị xoá khi kích hoạt power tile [kind] tại (row, col) — cả
  /// hàng/cột (line), vùng 5x5 quanh tâm (bomb), hoặc toàn bộ ô cùng màu trên
  /// bàn (rainbow). Hàm thuần (không side-effect) để [_activatePowerTile] tái
  /// dùng khi tính vùng nổ cộng hưởng (F5d) của 1 power tile khác.
  Set<Point<int>> _blastCellsFor(int row, int col, PowerTileKind kind) {
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
    return cells;
  }

  /// F5: kích hoạt power tile tại (row, col).
  void _activatePowerTile(int row, int col, PowerTileKind kind) {
    _saveUndo();
    final cells = _blastCellsFor(row, col, kind);
    if (cells.isEmpty) return;
    // F5d (stretch goal): vùng nổ vướng phải power tile khác → kích hoạt kèm
    // vùng nổ của tile đó luôn (gộp 1 đợt xoá), thưởng gấp đôi điểm.
    final resonant = cells
        .where((p) => !(p.x == row && p.y == col))
        .where((p) => _blocks[p.x][p.y]?.powerKind != null)
        .toList();
    for (final p in resonant) {
      cells.addAll(_blastCellsFor(p.x, p.y, _blocks[p.x][p.y]!.powerKind!));
    }
    // I28: xem lại phần chú thích ở [_tryPop] — không cộng điểm/combo thật khi replay.
    final gained = isReplay
        ? scoreForGroup(cells.length) * (resonant.isEmpty ? 1 : 2)
        : controller.registerPop(
            scoreForGroup(cells.length) * (resonant.isEmpty ? 1 : 2),
            groupSize: cells.length,
          );
    _comboTimer =
        controller.activeComboWindowOverride ?? GameController.comboWindow;
    final gemColor = NeonTheme
        .gemColors[(colorGrid[row][col] ?? 0) % NeonTheme.gemColors.length];
    _spawnScorePopup(
      row,
      col,
      gained,
      controller.comboMultiplier.value,
      gemColor,
    );
    if (resonant.isNotEmpty ||
        cells.length >= _bigGroupThreshold ||
        controller.comboMultiplier.value >= _bigComboThreshold) {
      controller.triggerFlash();
    }
    // I39: mốc combo cố định → text "COMBO x{N}!" + rung mạnh hơn.
    if (isComboMilestone(controller.comboCount.value)) {
      controller.triggerComboMilestone(controller.comboCount.value);
      fireHaptic(hapticForComboMilestone(controller.comboCount.value));
    }
    final broken = _chipObstaclesOrFrozen(cells);
    final bossBroken = _chipAdjacentBossTiles(cells);
    chipAdjacentLocks(lockGrid, cells);
    _syncObstacleAndLockBlocks();
    _clearAndCollapse(
      cells
        ..addAll(broken)
        ..addAll(bossBroken),
    );
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
    if (_shakeCooldownTimer > 0) _shakeCooldownTimer -= dt;
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
    // I31: gợi ý thủ công tự tắt sau [_manualHintDur]s, khác gợi ý idle ở
    // trên vốn đứng yên tới khi tap.
    if (_manualHintTimer > 0) {
      _manualHintTimer -= dt;
      if (_manualHintTimer <= 0) clearHint();
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
    _manualHintTimer = 0;
  }

  /// I31: gợi ý bấm-thủ-công (nút Hint trong booster bar) — hiện ngay nhóm
  /// lớn nhất, bỏ qua [_hintDelay] rảnh tay, tự tắt sau [_manualHintDur]s
  /// thay vì đợi tap kế tiếp. Trả false nếu đang animate, gợi ý đã đang hiện
  /// sẵn (từ idle-trigger I4 hoặc từ lần bấm trước), hoặc bàn không còn nhóm
  /// ≥2 — caller (`GameController.useHint`) dựa vào đó để không trừ nhầm lượt
  /// hint khi không có gì mới để gợi ý (tránh double-spend: bấm nút trong lúc
  /// gợi ý idle đang hiện sẽ vừa tốn lượt vừa rút ngắn thời gian hiện xuống
  /// còn 1.5s một cách vô ích).
  bool showHint() {
    if (_animating || _hint.isNotEmpty) return false;
    final group = findLargestGroup(colorGrid, lockGrid: lockGrid);
    if (group.isEmpty) return false;
    _hint = group;
    for (final p in group) {
      _blocks[p.x][p.y]?.hinted = true;
    }
    _manualHintTimer = _manualHintDur;
    return true;
  }

  /// Trả về false nếu không có gì bị nổ (đang animate, hoặc 3x3 quanh
  /// (row,col) toàn obstacle/lock) — caller dùng để tránh trừ nhầm lượt booster.
  bool triggerBomb(int row, int col) {
    if (_animating) return false;
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
    if (cells.isEmpty) return false;
    recordingValid = false;
    fireHaptic(HapticLevel.heavy);
    final broken = _chipObstaclesOrFrozen(cells);
    final bossBroken = _chipAdjacentBossTiles(cells);
    chipAdjacentLocks(lockGrid, cells);
    _syncObstacleAndLockBlocks();
    _spawnBombShockwave(_cellCenter(row, col));
    _clearAndCollapse(
      cells
        ..addAll(broken)
        ..addAll(bossBroken),
    );
    return true;
  }

  /// F3: xoá mọi ô cùng màu với ô (row, col) trên toàn bàn. Trả về false nếu
  /// không có gì bị nổ (đang animate, ô target là obstacle, hoặc mọi ô cùng
  /// màu đều đang bị khoá) — caller dùng để tránh trừ nhầm lượt booster.
  bool triggerRainbow(int row, int col) {
    if (_animating) return false;
    final targetColor = colorGrid[row][col];
    // F6a: obstacle không có "màu" thật → không cho kích hoạt rainbow trên nó.
    if (targetColor == null || targetColor < 0) return false;
    _saveUndo();
    final cells = <Point<int>>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (colorGrid[r][c] == targetColor && lockGrid[r][c] == 0) {
          cells.add(Point(r, c));
        }
      }
    }
    if (cells.isEmpty) return false;
    recordingValid = false;
    final broken = _chipObstaclesOrFrozen(cells);
    final bossBroken = _chipAdjacentBossTiles(cells);
    chipAdjacentLocks(lockGrid, cells);
    _syncObstacleAndLockBlocks();
    _clearAndCollapse(
      cells
        ..addAll(broken)
        ..addAll(bossBroken),
    );
    return true;
  }

  /// F10: đổi màu 2 ô bất kỳ (không cần liền kề), không tự nổ. Bỏ qua obstacle/
  /// chain tile (không có "màu" thật để đổi). Trả về false nếu không đổi được
  /// (đang animate, hoặc 1 trong 2 ô là obstacle/lock) — caller dùng để tránh
  /// trừ nhầm lượt booster.
  bool triggerSwap(int row1, int col1, int row2, int col2) {
    if (_animating) return false;
    if ((colorGrid[row1][col1] ?? -1) < 0 || lockGrid[row1][col1] != 0) {
      return false;
    }
    if ((colorGrid[row2][col2] ?? -1) < 0 || lockGrid[row2][col2] != 0) {
      return false;
    }
    _saveUndo();
    recordingValid = false;
    final tmp = colorGrid[row1][col1];
    colorGrid[row1][col1] = colorGrid[row2][col2];
    colorGrid[row2][col2] = tmp;
    _swapFlip(_blocks[row1][col1], colorGrid[row1][col1]!);
    _swapFlip(_blocks[row2][col2], colorGrid[row2][col2]!);
    _checkEnd();
    return true;
  }

  /// A9: lật ô theo trục dọc rồi đổi màu ở giữa chừng (ScaleEffect.to hỗ trợ
  /// onComplete riêng dù nằm trong SequenceEffect) thay vì đổi màu tức thì.
  void _swapFlip(BlockComponent? b, int newColor) {
    if (b == null) return;
    b.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2(1, 0),
          EffectController(duration: 0.09, curve: Curves.easeIn),
          onComplete: () => b.colorIndex = newColor,
        ),
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.09, curve: Curves.easeOut),
        ),
      ]),
    );
  }

  /// Xoá [cells]: animate pop từng ô + hạt, rồi rơi/dồn bằng tween, cuối cùng
  /// đồng bộ colorGrid và kiểm tra kết thúc.
  void _clearAndCollapse(Set<Point<int>> cells) {
    _animating = true;
    // Vô hiệu hoá timer hạ `_animating=false` của bất kỳ operation ngoài nào
    // (shuffle/undo/rebuild) đã tự lên lịch trước đó rồi mới gọi `_checkEnd()`
    // kích hoạt collapse này (vd shuffle xong vẫn kẹt bàn còn boss tile).
    _animGen++;
    _maybeTriggerPunch(cells);
    _maybeTriggerShake(cells);
    if (cells.isNotEmpty) {
      final first = cells.first;
      // I29: cell của tập [cells] có thể ĐÃ null khi gọi tới (vd boss tile vỡ
      // do decay-on-stuck tự null hoá TRƯỚC khi gọi hàm này) — fallback về 0
      // thay vì non-null assertion để không crash.
      final ringColor =
          NeonTheme.gemColors[(colorGrid[first.x][first.y] ?? 0) %
              NeonTheme.gemColors.length];
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
    // G9/A9: nhóm càng to càng "đã" (nhiều hạt hơn), nhưng vẫn trần tổng
    // ngân sách hạt toàn cụm để tránh spike draw call khi clear 20-30+ ô.
    final baseCount = (6 + (cells.length - 1) * 1.2).clamp(6, 16).round();
    const totalBudget = 140;
    final burstCount = cells.length <= 8
        ? baseCount
        : (totalBudget / cells.length).clamp(6, baseCount).round();
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
    if (_reduceMotion || _punchCooldownTimer > 0) return;
    final bigGroup = cells.length >= _punchGroupThreshold;
    final bigCombo = controller.comboMultiplier.value >= _punchComboThreshold;
    if (!bigGroup && !bigCombo) return;
    _slowMoTimer = _slowMoDur;
    _punchCooldownTimer = _punchCooldownDur;
    final (minR, maxR, minC, maxC) = _effectRegion(cells);
    for (var r = minR; r <= maxR; r++) {
      for (var c = minC; c <= maxC; c++) {
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

  /// A1: nhóm ≥[_shakeGroupThreshold] ô → bàn rung nhẹ. Camera thật không
  /// dùng được (xem ghi chú [_maybeTriggerPunch]) nên rung bằng cách offset
  /// vị trí từng block 1 nhịp qua-lại-về (tổng dịch chuyển = 0, không cần
  /// lưu/khôi phục vị trí gốc). Không đụng ô vừa bị xoá (đã có scale pop riêng).
  void _maybeTriggerShake(Set<Point<int>> cells) {
    if (_reduceMotion ||
        _shakeCooldownTimer > 0 ||
        cells.length < _shakeGroupThreshold) {
      return;
    }
    _shakeCooldownTimer = _shakeCooldownDur;
    final amp = cellSize * 0.12;
    final (minR, maxR, minC, maxC) = _effectRegion(cells);
    for (var r = minR; r <= maxR; r++) {
      for (var c = minC; c <= maxC; c++) {
        if (cells.contains(Point(r, c))) continue;
        final b = _blocks[r][c];
        if (b == null) continue;
        b.add(
          SequenceEffect([
            MoveByEffect(Vector2(amp, 0), EffectController(duration: 0.04)),
            MoveByEffect(
              Vector2(-amp * 2, 0),
              EffectController(duration: 0.04),
            ),
            MoveByEffect(Vector2(amp, 0), EffectController(duration: 0.04)),
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

  /// cap [_maxBursts] particle system (spark/confetti/starburst) chạy đồng
  /// thời, cùng lý do [_spawnRing]. I17-fix: bản trước lazy-prune bằng
  /// [isMounted], nhưng `add()` chỉ mount ở lifecycle pass sau — nhiều burst
  /// add liên tiếp trong 1 lần pop nhóm lớn đều "chưa mounted" nên bị coi là
  /// đã xong, xoá sạch tracking list và làm cap vô hiệu. Dùng [RemoveEffect]
  /// với [lifespan] biết trước (giống [onFinish] của [_spawnRing]) để prune
  /// đúng lúc burst thật sự kết thúc, không phụ thuộc timing mount.
  void _trackBurst(ParticleSystemComponent c, double lifespan) {
    if (_bursts.length >= _maxBursts) {
      _bursts.removeAt(0).removeFromParent();
    }
    _bursts.add(c);
    c.add(RemoveEffect(delay: lifespan, onComplete: () => _bursts.remove(c)));
    add(c);
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

  /// E2-S6: 2 ring bung nối tiếp (cam rồi đỏ) tại tâm 3x3 của Bomb — tách hẳn
  /// khỏi ring pop thường, tái dùng [_spawnRing] có sẵn (không component mới).
  void _spawnBombShockwave(Vector2 center) {
    _spawnRing(center, NeonTheme.orange, cellSize * 1.6);
    add(
      TimerComponent(
        period: 0.08,
        removeOnFinish: true,
        onTick: () => _spawnRing(center, NeonTheme.red, cellSize * 2.0),
      ),
    );
  }

  void _collapseAnimated() {
    // I3: gravity theo hướng màn — down chạy thẳng, hướng khác quy về không
    // gian "down" (transpose/lật trục), nén rồi quy ngược lại (xem
    // transformForDirection/compactNonNullDown trong pop_collapse.dart).
    final direction = controller.currentLevel.gravityDirection;
    if (direction == GravityDirection.down) {
      compactNonNullDown(_blocks);
    } else {
      final work = transformForDirection(_blocks, direction);
      compactNonNullDown(work);
      _blocks = transformForDirection(work, direction, inverse: true);
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
          _maybeTagTimeFreezeTile();
          _checkEnd();
        },
      ),
    );
  }

  /// I44: sau mỗi lần collapse hoàn tất, có xác suất nhỏ gắn tag Time Freeze
  /// lên 1 ô màu hợp lệ — chỉ ở Time Attack, tối đa 1 ô/bàn, né ô đang có
  /// hiệu ứng đặc biệt khác (obstacle/gift/boss/lockGrid/powerKind).
  void _maybeTagTimeFreezeTile() {
    if (controller.mode.value != GameMode.timeAttack) return;
    final alreadyTagged = _blocks.any(
      (row) => row.any((b) => b?.timeFreezeTagged == true),
    );
    final candidates = <int>[
      for (var idx = 0; idx < rows * cols; idx++)
        if ((colorGrid[idx ~/ cols][idx % cols] ?? -1) >= 0 &&
            lockGrid[idx ~/ cols][idx % cols] == 0 &&
            _blocks[idx ~/ cols][idx % cols]?.powerKind == null)
          idx,
    ];
    if (candidates.isEmpty) return;
    if (!shouldTagTimeFreezeTile(
      isTimeAttack: true,
      alreadyTagged: alreadyTagged,
      rng: _rng,
    )) {
      return;
    }
    final idx = candidates[_rng.nextInt(candidates.length)];
    _blocks[idx ~/ cols][idx % cols]?.timeFreezeTagged = true;
  }

  /// I44: side-effect độc lập với score/combo — cộng +10s vào đồng hồ Time
  /// Attack. `PopStarGame` không giữ tham chiếu `GameScreenController` nên
  /// cần `Get.find` (tương tự cách I43 gọi `Get.find<BossRushController>()`);
  /// an toàn vì chỉ được gọi khi ô đã tag, và ô chỉ được tag ở Time Attack —
  /// mode duy nhất luôn đăng ký `GameScreenController` trước khi vào game.
  void _triggerTimeFreeze() {
    Get.find<GameScreenController>().remainingSeconds.value += 10;
  }

  /// Popup "+điểm" (kèm "xN" nếu combo) bay lên rồi biến mất tại ô vừa tap.
  /// [gemColor]: màu nhóm gem vừa nổ — nhuộm popup theo màu đó thay vì
  /// trắng/cam cố định, khớp aesthetic neon-glow chung của game.
  void _spawnScorePopup(
    int row,
    int col,
    int gained,
    double mult,
    Color gemColor,
  ) {
    final combo = mult > 1.0;
    final multTxt = mult == mult.roundToDouble()
        ? mult.toStringAsFixed(0)
        : mult.toStringAsFixed(1);
    final txt = combo ? '+$gained  x$multTxt' : '+$gained';
    // combo cao → chữ to hơn + rung nhẹ, "phô" hơn (giống cảm giác punch ở
    // _maybeTriggerPunch nhưng dành riêng cho popup, không đụng toàn bàn).
    final punch = ((mult - 1) / (GameController.comboMax - 1)).clamp(0.0, 1.0);
    final fontSize = cellSize * (combo ? 0.42 : 0.34) * (1 + punch * 0.3);
    final pos = _cellCenter(row, col);
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
    );

    // quầng glow màu gem phía sau chữ — chỉ 1 popup/lần (không phải
    // full-board như heat rim), nên blur ở đây không đụng lại vấn đề hiệu
    // suất vừa fix.
    final glow = CircleComponent(
      radius: fontSize * 0.85,
      anchor: Anchor.center,
      priority: 0,
      paint: Paint()
        ..color = gemColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    final strokeText = TextComponent(
      text: txt,
      anchor: Anchor.center,
      priority: 1,
      textRenderer: TextPaint(
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.09
            ..strokeJoin = StrokeJoin.round
            ..color = NeonTheme.ink,
        ),
      ),
    );
    final fillText = TextComponent(
      text: txt,
      anchor: Anchor.center,
      priority: 2,
      textRenderer: TextPaint(style: style.copyWith(color: gemColor)),
    );
    final root = PositionComponent(
      position: pos,
      anchor: Anchor.center,
      priority: 100,
      scale: Vector2.zero(),
    )..addAll([glow, strokeText, fillText]);
    root.add(
      MoveByEffect(
        Vector2(0, -cellSize * 1.3),
        EffectController(duration: 0.6, curve: Curves.easeOut),
      ),
    );
    root.add(
      ScaleEffect.to(
        Vector2.all(1 + punch * 0.15),
        EffectController(duration: 0.25, curve: Curves.easeOutBack),
      ),
    );
    root.add(RemoveEffect(delay: 0.6));
    add(root);
    _spawnScoreSparkles(pos, gemColor);
  }

  /// Vài hạt lấp lánh bay theo hướng popup điểm (tái dùng kỹ thuật
  /// ComputedParticle không-blur đã tối ưu ở [_spawnBurst], chỉ đổi hướng
  /// bay hẹp lên trên thay vì nổ toả tròn).
  void _spawnScoreSparkles(Vector2 at, Color color) {
    const lifespan = 0.5;
    add(
      ParticleSystemComponent(
        position: at,
        particle: Particle.generate(
          count: 4,
          generator: (i) {
            final a = -pi / 2 + (_rng.nextDouble() - 0.5) * 0.9;
            final speed = 50 + _rng.nextDouble() * 60;
            final vel = Vector2(cos(a), sin(a)) * speed;
            return ComputedParticle(
              lifespan: lifespan,
              renderer: (canvas, particle) {
                final t = particle.progress * lifespan;
                final pos = vel * t;
                final alpha = (1 - particle.progress).clamp(0.0, 1.0);
                canvas.drawCircle(
                  Offset(pos.x, pos.y),
                  cellSize * 0.035,
                  Paint()..color = color.withValues(alpha: alpha * 0.85),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// I52: dispatcher — chọn hàm vẽ hiệu ứng nổ theo [_activeBurstKind].
  /// Ripple tái dùng thẳng [_spawnRing] đã có, không viết particle mới.
  void _spawnBurst(Vector2 at, Color color, {int count = 10}) {
    switch (_activeBurstKind) {
      case BurstStyleKind.spark:
        _spawnSparkBurst(at, color, count: count);
      case BurstStyleKind.confetti:
        _spawnConfettiBurst(at, count: count);
      case BurstStyleKind.ripple:
        _spawnRing(at, color, cellSize * 0.9);
      case BurstStyleKind.starburst:
        _spawnStarburstBurst(at, color, count: count);
    }
  }

  /// Hạt nổ + vệt sáng (G2): tự tính vị trí theo gia tốc để vẽ trail mờ dần
  /// dọc hướng bay (rẻ hơn nhiều so với ghép AcceleratedParticle + sprite).
  void _spawnSparkBurst(Vector2 at, Color color, {int count = 10}) {
    const lifespan = 0.5;
    final accel = Vector2(0, 220);
    _trackBurst(
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
      lifespan,
    );
  }

  /// I52: giống [_spawnSparkBurst] (cùng ballistic model — không đổi thời
  /// lượng animation tổng thể) nhưng vẽ hình vuông nhỏ xoay random, màu
  /// cycle qua [NeonTheme.gemColors] thay vì 1 màu cố định.
  void _spawnConfettiBurst(Vector2 at, {int count = 10}) {
    const lifespan = 0.5;
    final accel = Vector2(0, 220);
    _trackBurst(
      ParticleSystemComponent(
        position: at,
        particle: Particle.generate(
          count: count,
          generator: (i) {
            final a = _rng.nextDouble() * pi * 2;
            final speed = 60 + _rng.nextDouble() * 90;
            final vel = Vector2(cos(a), sin(a)) * speed;
            final spin = (_rng.nextDouble() - 0.5) * 12;
            final color = NeonTheme.gemColors[i % NeonTheme.gemColors.length];
            final size = cellSize * 0.16;
            return ComputedParticle(
              lifespan: lifespan,
              renderer: (canvas, particle) {
                final t = particle.progress * lifespan;
                final pos = vel * t + accel * (0.5 * t * t);
                final alpha = (1 - particle.progress).clamp(0.0, 1.0);
                canvas.save();
                canvas.translate(pos.x, pos.y);
                canvas.rotate(spin * t);
                canvas.drawRect(
                  Rect.fromCenter(
                    center: Offset.zero,
                    width: size,
                    height: size,
                  ),
                  Paint()..color = color.withValues(alpha: alpha * 0.9),
                );
                canvas.restore();
              },
            );
          },
        ),
      ),
      lifespan,
    );
  }

  /// I52: giống [_spawnSparkBurst] (cùng ballistic model) nhưng vẽ 1 sao
  /// 5 cánh xoay thay vì vệt tròn.
  void _spawnStarburstBurst(Vector2 at, Color color, {int count = 10}) {
    const lifespan = 0.5;
    final accel = Vector2(0, 220);
    _trackBurst(
      ParticleSystemComponent(
        position: at,
        particle: Particle.generate(
          count: count,
          generator: (i) {
            final a = _rng.nextDouble() * pi * 2;
            final speed = 60 + _rng.nextDouble() * 90;
            final vel = Vector2(cos(a), sin(a)) * speed;
            final spin = (_rng.nextDouble() - 0.5) * 10;
            final size = cellSize * 0.16;
            return ComputedParticle(
              lifespan: lifespan,
              renderer: (canvas, particle) {
                final t = particle.progress * lifespan;
                final pos = vel * t + accel * (0.5 * t * t);
                final alpha = (1 - particle.progress).clamp(0.0, 1.0);
                canvas.save();
                canvas.translate(pos.x, pos.y);
                canvas.rotate(spin * t);
                canvas.drawPath(
                  _starPath(size),
                  Paint()..color = color.withValues(alpha: alpha * 0.9),
                );
                canvas.restore();
              },
            );
          },
        ),
      ),
      lifespan,
    );
  }

  /// I52: `Path` sao 5 cánh tâm gốc toạ độ, bán kính ngoài [size].
  static Path _starPath(double size) {
    final path = Path();
    const spikes = 5;
    final outerR = size / 2;
    final innerR = outerR * 0.45;
    for (var i = 0; i < spikes * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final a = i * pi / spikes - pi / 2;
      final x = cos(a) * r;
      final y = sin(a) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  /// Trả về false nếu đang animate (không xáo được) — caller dùng để tránh
  /// trừ nhầm lượt booster.
  bool shuffleBoard() {
    if (_animating) return false;
    recordingValid = false;
    _saveUndo();
    // F6a: obstacle không phải màu → giữ nguyên vị trí/độ bền, chỉ xáo màu thật.
    // I2: ô đang khoá cũng giữ nguyên (không xáo màu vào/ra chain tile).
    final movable = [
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++)
          if ((colorGrid[r][c] ?? -1) >= 0 && lockGrid[r][c] == 0) Point(r, c),
    ];
    // E2-S7: xáo chính các BlockComponent (không chỉ giá trị màu int) rồi bay
    // tại chỗ sang vị trí mới — không phá huỷ/rơi lại từ ngoài bảng như trước.
    final blocks = [for (final p in movable) _blocks[p.x][p.y]];
    blocks.shuffle(_rng);
    _animating = true;
    final gen = ++_animGen;
    for (var i = 0; i < movable.length; i++) {
      final p = movable[i];
      final b = blocks[i];
      _blocks[p.x][p.y] = b;
      colorGrid[p.x][p.y] = b?.colorIndex;
      if (b == null) continue;
      final target = _cellCenter(p.x, p.y);
      if ((b.position - target).length2 > 0.01) {
        b.add(
          MoveToEffect(
            target,
            EffectController(duration: _fallDur, curve: Curves.easeOutBack),
          ),
        );
      }
    }
    add(
      TimerComponent(
        period: _fallDur,
        removeOnFinish: true,
        // Codex review: chỉ hạ khoá nếu chưa bị `_checkEnd()` bên dưới kích
        // hoạt 1 animation MỚI đè lên (vd bàn vẫn kẹt còn boss tile →
        // `_clearAndCollapse` chạy tiếp, cần khoá lâu hơn `_fallDur` này).
        onTick: () {
          if (_animGen == gen) _animating = false;
        },
      ),
    );
    _checkEnd();
    return true;
  }

  bool undo() {
    if (_animating) return false;
    final saved = _undoGrid;
    final savedLocks = _undoLockGrid;
    if (saved == null) return false;
    recordingValid = false;

    // E2-S8: gom sẵn các BlockComponent đang sống (post-collapse) theo màu,
    // trước khi ghi đè colorGrid — dùng làm nguồn bay ngược lại cho ô nào ở
    // grid khôi phục vẫn giữ được (chỉ trôi dạt do collapse).
    // ponytail: match theo colorIndex, không track ID vật lý từng viên —
    // người chơi không phân biệt được 2 viên cùng màu nên chấp nhận được.
    final pool = <int, List<BlockComponent>>{};
    for (final row in _blocks) {
      for (final b in row) {
        if (b == null) continue;
        // Codex review: huỷ effect còn dở trên block (vd `_swapFlip` từ
        // `triggerSwap` gọi ngay trước đó — cố ý KHÔNG set `_animating` nên
        // undo() không bị guard chặn, xem test I28 ở replay_recording_test).
        // Nếu không huỷ, effect cũ hoàn tất muộn hơn sẽ tự ý ghi đè
        // `colorIndex` (màu sau-swap) đè lên trạng thái vừa được undo khôi
        // phục.
        b.removeAll(b.children.whereType<Effect>().toList());
        pool.putIfAbsent(b.colorIndex, () => []).add(b);
      }
    }

    colorGrid = saved;
    if (savedLocks != null) lockGrid = savedLocks;
    // I29: khôi phục HP boss tile đúng thời điểm snapshot — `bossHp` là
    // `final Map` nên restore bằng clear+addAll thay vì gán lại.
    final savedBossHp = _undoBossHp;
    if (savedBossHp != null) {
      bossHp
        ..clear()
        ..addAll(savedBossHp);
    }
    // I45: khôi phục Countdown Lock đúng thời điểm snapshot, mirror pattern
    // bossHp ở trên.
    final savedCountdown = _undoCountdownRemaining;
    if (savedCountdown != null) {
      countdownRemaining
        ..clear()
        ..addAll(savedCountdown);
    }
    _undoGrid = null;
    _undoLockGrid = null;
    _undoBossHp = null;
    _undoCountdownRemaining = null;
    // Hoàn tác điểm/combo về đúng thời điểm snapshot — thiếu bước này thì
    // pop → undo (giữ điểm) → pop lại đúng nhóm đó sẽ farm điểm vô hạn.
    final savedScore = _undoScore;
    if (savedScore != null) {
      controller.score.value = savedScore;
      controller.comboCount.value = _undoComboCount!;
      controller.comboMultiplier.value = _undoComboMultiplier!;
      controller.movesUsed.value = _undoMovesUsed!;
    }
    _undoScore = null;
    _undoComboCount = null;
    _undoComboMultiplier = null;
    _undoMovesUsed = null;

    clearHint();
    _animating = true;
    final gen = ++_animGen;
    final material = materialForLevel(controller.currentLevel.id);
    final next = List.generate(
      rows,
      (_) => List<BlockComponent?>.filled(cols, null),
    );
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final color = colorGrid[r][c];
        if (color == null) continue;
        final target = _cellCenter(r, c);
        final candidates = pool[color];
        final reused = (candidates != null && candidates.isNotEmpty)
            ? candidates.removeLast()
            : null;
        if (reused != null) {
          next[r][c] = reused;
          if ((reused.position - target).length2 > 0.01) {
            reused.add(
              MoveToEffect(
                target,
                EffectController(duration: _fallDur, curve: Curves.easeOutBack),
              ),
            );
          }
        } else {
          // Ô đã bị pop mất thật — không có "vị trí hiện tại" để bay từ đó,
          // xuất hiện lại bằng scale-in (đảo ngược animation pop-biến-mất).
          final b = BlockComponent(
            colorIndex: color,
            lockCount: lockGrid[r][c],
            position: target,
            size: Vector2.all(cellSize),
            material: material,
          )..scale = Vector2.zero();
          add(b);
          b.add(
            ScaleEffect.to(
              Vector2.all(1),
              EffectController(duration: _fallDur, curve: Curves.easeOutBack),
            ),
          );
          next[r][c] = b;
        }
      }
    }
    // Block thừa không map được vào ô nào ở grid khôi phục (hiếm, ví dụ
    // obstacle đổi độ bền giữa lúc snapshot và lúc undo) hết chỗ đứng — bỏ.
    for (final leftovers in pool.values) {
      for (final b in leftovers) {
        b.removeFromParent();
      }
    }
    _blocks = next;
    _syncObstacleAndLockBlocks();
    add(
      TimerComponent(
        period: _fallDur,
        removeOnFinish: true,
        onTick: () {
          if (_animGen == gen) _animating = false;
        },
      ),
    );
    return true;
  }

  void _saveUndo() {
    _undoGrid = colorGrid.map((row) => List<int?>.from(row)).toList();
    _undoLockGrid = lockGrid.map((row) => List<int>.from(row)).toList();
    _undoBossHp = Map<int, int>.from(bossHp);
    _undoCountdownRemaining = Map<int, int>.from(countdownRemaining);
    if (!isReplay) {
      _undoScore = controller.score.value;
      _undoComboCount = controller.comboCount.value;
      _undoComboMultiplier = controller.comboMultiplier.value;
      _undoMovesUsed = controller.movesUsed.value;
    }
  }

  void _checkEnd() {
    // I1: gift rơi tới hàng đáy sau gravity → tự mở + cộng thưởng ngay.
    for (final c in openGiftsAtBottomRow(colorGrid)) {
      _blocks[rows - 1][c]?.removeFromParent();
      _blocks[rows - 1][c] = null;
      // I28: LUÔN bốc rng ở cả 2 mode để giữ đúng thứ tự tiêu thụ _rng cho
      // các lượt bốc kế tiếp (power tile, shuffle...) — chỉ phát thưởng thật
      // khi không phải replay (xem [isReplay]). Tách bốc số khỏi phát thưởng
      // để tránh lệch RNG giữa record/replay (bug đã audit, xem doc/feat.md).
      final reward = pickGiftReward(_rng);
      if (!isReplay) controller.grantGiftReward(reward);
    }
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
        !hasAnyMovableGroup(
          colorGrid,
          lockGrid: lockGrid,
          minGroupSize: controller.activeMinGroupSize,
        ) &&
        !hasPowerTile;
    // I29: bàn kẹt nhưng còn boss tile chưa vỡ (không còn gem thường liền kề
    // để nổ nứt boss) → tự giảm 1 HP mọi boss tile thay vì kết thúc màn ngay,
    // tránh softlock. PHẢI gọi `_clearAndCollapse`/`return` VÔ ĐIỀU KIỆN mỗi
    // khi còn boss tile — kể cả lúc `bossDecayBroken` rỗng (decay chưa làm vỡ
    // tile nào) — vì `_clearAndCollapse` (dù cells rỗng) vẫn lên lịch
    // `TimerComponent` gọi lại `_checkEnd()` sau animation; nếu gate theo
    // `isNotEmpty` như code cũ thì màn kết thúc "kẹt" ngay lần decay đầu tiên
    // (mọi boss tile thật đều startHp >= 6, không bao giờ vỡ ở lần trừ đầu),
    // vô hiệu hoá hoàn toàn cơ chế chống softlock. Vòng lặp bị chặn tự nhiên
    // bởi tổng HP boss (tối đa 16 lần, chỉ 1 boss tile/màn — không có nguy cơ
    // vô hạn).
    if (stuck && bossHp.isNotEmpty) {
      final before = Map<int, int>.from(bossHp);
      final bossDecayBroken = decayBossTilesOnStuck(colorGrid, bossHp);
      _spawnBossChipRingsForDecrement(before);
      _syncObstacleAndLockBlocks();
      _clearAndCollapse(bossDecayBroken);
      return;
    }
    // I28: replay chỉ dựng lại bàn để xem — campaign-only (không endless/
    // refill/objective riêng) nên chỉ cần biết bàn đã dọn sạch/kẹt hẳn chưa,
    // không gọi bất kỳ method persist thật nào của [controller].
    if (isReplay) {
      if (remaining == 0 || stuck) replayEnded = true;
      return;
    }
    // F12: Endless — dọn sạch (remaining == 0) thì sang bàn kế khó hơn, giữ
    // nguyên điểm; chỉ thật sự kết thúc ván khi bàn kẹt hẳn (stuck).
    if (controller.mode.value == GameMode.endless) {
      if (remaining == 0) {
        _nextEndlessBoard();
      } else if (stuck) {
        controller.checkEnd(false);
      }
      return;
    }
    // I47 Mirror Mode: dọn sạch → bàn mới đối xứng gương, giữ nguyên điểm
    // (mirror [GameMode.endless], bàn không ramp độ khó vì [kMirrorModeLevel]
    // cố định); kẹt hẳn mới dừng ván thật.
    if (controller.mode.value == GameMode.mirrorMode) {
      if (remaining == 0) {
        _nextMirrorBoard();
      } else if (stuck) {
        controller.checkEnd(false);
      }
      return;
    }
    // I43: Boss Rush — dọn sạch thì sang bàn boss kế (stage tăng, chuỗi giữ
    // nguyên điểm/streak); kẹt hẳn mới dừng chuỗi thật (checkEnd(false) tự
    // fallthrough đúng ở [GameController.checkEnd], [BossRushController]
    // lắng nghe `ended` để chốt best-streak/coin).
    if (controller.mode.value == GameMode.bossRush) {
      if (remaining == 0) {
        _nextBossRushBoard();
      } else if (stuck) {
        controller.checkEnd(false);
      }
      return;
    }
    if (refillEnabled && (remaining == 0 || stuck)) {
      _refillBoard();
      return;
    }
    controller.updateObjectiveProgress(colorGrid);
    final hardMoveLimit = controller.activeMoveLimit;
    if (hardMoveLimit != null && controller.movesUsed.value >= hardMoveLimit) {
      controller.checkEnd(remaining == 0);
      return;
    }
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

  /// F12: bàn Endless kế tiếp — khó hơn bàn vừa dọn xong (rows/cols/colors
  /// tăng theo [GameController.advanceEndlessBoard]), nên phải dựng lại
  /// [_layout] chứ không chỉ regenerate màu như [_refillBoard] (bàn Zen giữ
  /// nguyên kích thước).
  void _nextEndlessBoard() {
    final level = controller.advanceEndlessBoard();
    rows = level.rows;
    cols = level.cols;
    colorGrid = List.generate(
      rows,
      (_) => List.generate(cols, (_) => _rng.nextInt(level.colorCount)),
    );
    lockGrid = List.generate(rows, (_) => List.generate(cols, (_) => 0));
    _layout();
    _rebuildBoard();
  }

  /// I47 Mirror Mode: bàn kế tiếp — kích thước cố định ([kMirrorModeLevel])
  /// nên không cần [_layout] lại như [_nextEndlessBoard], chỉ regenerate màu
  /// đối xứng gương như [_refillBoard].
  void _nextMirrorBoard() {
    final level = controller.currentLevel;
    colorGrid = generateMirrorBoard(
      level.rows,
      level.cols,
      level.colorCount,
      _rng,
    ).map((row) => List<int?>.of(row)).toList();
    lockGrid = List.generate(rows, (_) => List.generate(cols, (_) => 0));
    _rebuildBoard();
  }

  /// I43: bàn Boss Rush kế tiếp — mirror [_nextEndlessBoard] nhưng mọi bàn
  /// đều có boss tile nên phải clear [bossHp] cũ rồi đặt lại boss tile mới
  /// (khác Endless — không có boss tile).
  void _nextBossRushBoard() {
    final level = Get.find<BossRushController>().advanceStage();
    rows = level.rows;
    cols = level.cols;
    colorGrid = List.generate(
      rows,
      (_) => List.generate(cols, (_) => _rng.nextInt(level.colorCount)),
    );
    lockGrid = List.generate(rows, (_) => List.generate(cols, (_) => 0));
    bossHp.clear();
    _placeBossTileIfNeeded(level);
    _layout();
    _rebuildBoard();
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
    final direction = controller.currentLevel.gravityDirection;
    final material = materialForLevel(controller.currentLevel.id);
    var maxDelay = 0.0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final color = colorGrid[r][c];
        if (color == null) continue;
        final target = _cellCenter(r, c);
        final b = BlockComponent(
          colorIndex: color,
          lockCount: lockGrid[r][c],
          // I29: gán HP boss tile ngay lúc dựng block, không chờ
          // `_syncObstacleAndLockBlocks` (chỉ chạy sau chip-hook) — tránh
          // hiển thị sai (thiếu số HP) ngay sau khi vào màn/undo/replay.
          bossHp: isBossTileId(color) ? bossHp[color] : null,
          // I45: gán số đếm ngược ngay lúc dựng block, cùng lý do với bossHp
          // ở trên — tránh thiếu số ngay sau khi vào màn/undo/replay.
          countdownDisplay: isCountdownLockId(color)
              ? countdownRemaining[color]
              : null,
          position: animateIntro
              ? _introStart(r, c, target, direction)
              : target,
          size: Vector2.all(cellSize),
          material: material,
        );
        _blocks[r][c] = b;
        add(b);
        if (animateIntro) {
          final delay = (r + c) * _introStagger;
          if (delay > maxDelay) maxDelay = delay;
          void addFallEffect() => b.add(
            MoveToEffect(
              target,
              EffectController(
                duration: _introFallDur,
                curve: Curves.easeOutBack,
              ),
            ),
          );
          // I3: startDelay của EffectController dùng DelayedEffectController,
          // cần Effect nhận đủ 2 update-tick mới bắt đầu apply — trên máy yếu
          // (Tecno) tick thứ 2 có thể không tới, block kẹt vĩnh viễn ở vị trí
          // spawn. Dùng TimerComponent (đã verify chạy ổn định) để tự delay
          // thay vì phó mặc cho Flame.
          if (delay <= 0) {
            addFallEffect();
          } else {
            add(
              TimerComponent(
                period: delay,
                removeOnFinish: true,
                onTick: addFallEffect,
              ),
            );
          }
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

  /// I3: điểm xuất phát của block khi vào màn — luôn từ phía ngoài bức tường
  /// đối diện hướng gravity, so le theo khoảng cách tới vị trí đích (giống
  /// stagger gốc của [GravityDirection.down] dựa trên [r]).
  Vector2 _introStart(int r, int c, Vector2 target, GravityDirection dir) {
    switch (dir) {
      case GravityDirection.down:
        return Vector2(target.x, _boardTop - cellSize * (r + 2));
      case GravityDirection.up:
        return Vector2(
          target.x,
          _boardTop + rows * cellSize + cellSize * (rows - 1 - r + 2),
        );
      case GravityDirection.left:
        return Vector2(
          _boardLeft + cols * cellSize + cellSize * (cols - 1 - c + 2),
          target.y,
        );
      case GravityDirection.right:
        return Vector2(_boardLeft - cellSize * (c + 2), target.y);
    }
  }
}
