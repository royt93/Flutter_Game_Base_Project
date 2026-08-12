import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/haptics.dart';
import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../../data/worlds.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/prestige_action.dart';
import '../widgets/stroke_text.dart';
import 'game_screen.dart';

const double _tileSize = 64;
const double _bannerHeight = 60;
const double _minRowStep = 50;
const double _maxRowStep = 110;

/// F4: 200 node xếp theo đường uốn lượn, chia 10 world (mỗi world 20 màn) có
/// banner tên + tông màu riêng. Auto-scroll tới màn cao nhất mở khoá khi vào.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  bool _scrolled = false;
  late final _flowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  bool get _reduceMotion =>
      StorageService.maybe?.getBool(StorageKeys.reduceMotion) ?? false;

  /// P: `_flowCtrl` chạy vòng lặp liên tục (~60fps) và nuôi 2 CustomPainter
  /// (path glow + decor sparkle) phải vẽ lại hàng trăm-nghìn segment/dot của
  /// cả 220 level mỗi lần — kể cả khi màn hình đứng yên. Lượng tử hoá giá trị
  /// truyền vào painter xuống 60 nấc/chu kỳ (~30fps thật) giống pattern đã
  /// dùng ở `NeonBg`/`NeonAuraLayer`: AnimatedBuilder vẫn rebuild mỗi frame
  /// (rẻ) nhưng `shouldRepaint` chỉ true khi nấc đổi → vẽ lại đúng phân nửa
  /// tần suất, chuyển động vẫn mượt vì bước lượng tử đủ nhỏ.
  double get _throttledFlow => (_flowCtrl.value * 60).floorToDouble() / 60;

  /// Chạy 1 lần khi 1 đoạn path vừa được "mở khoá" — ánh sáng chạy dọc đoạn
  /// từ đầu tới cuối trong lúc [_revealId] còn khác null.
  late final _revealCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final _gameCtrl = Get.find<GameController>();
  late final Worker _justUnlockedWorker;
  int? _pendingReveal;
  int? _revealId;
  Timer? _revealClearTimer;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    if (!_reduceMotion) _flowCtrl.repeat();
    // Đăng ký ngay lúc tạo state — màn này không bị dispose khi push
    // GameScreen lên trên, nên phải lắng nghe cả lúc đang bị che.
    _justUnlockedWorker = ever<int?>(_gameCtrl.justUnlocked, (id) {
      if (id != null) _pendingReveal = id;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _flowCtrl.dispose();
    _revealCtrl.dispose();
    _revealClearTimer?.cancel();
    _justUnlockedWorker.dispose();
    super.dispose();
  }

  /// Haptic + path sáng chạy 1 lần tới node [id] + confetti burst, gọi ngay
  /// khi màn hình đang là route hiện tại và vừa phát hiện 1 unlock mới.
  void _playReveal(int id) {
    fireHaptic(HapticLevel.medium);
    setState(() {
      _revealId = id;
      _showConfetti = true;
    });
    _revealCtrl.forward(from: 0);
    _revealClearTimer?.cancel();
    _revealClearTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _revealId = null);
    });
    Future.delayed(const Duration(milliseconds: 2700), () {
      if (mounted) setState(() => _showConfetti = false);
    });
  }

  /// Tâm node id=1..kLevelCount + top của mỗi banner world, theo chiều rộng
  /// [width] hiện có. Không còn lưới thẳng hàng — mỗi node lệch ngang theo 2
  /// sóng sin cộng lại, biên độ gần sát mép màn hình. Cứ mỗi 3-6 node (seed
  /// cố định), tần số + biên độ sóng đổi ngẫu nhiên → vòng khi khít khi rộng
  /// xen kẽ, không lặp pattern. Khoảng cách dọc giữa 2 node cũng ngẫu nhiên
  /// [_minRowStep]..[_maxRowStep] (luôn > `_tileSize` nên 2 tile không bao
  /// giờ đè nhau) thay vì cố định — path đọc như thân rồng cuộn thật, dù
  /// đường cong (Catmull-Rom + wiggle ở `_buildSegments`) có vòng cắt qua
  /// chính nó.
  ({
    List<Offset> centers,
    List<double> bannerTops,
    double totalHeight,
    List<_PathSegment> segments,
    List<_DecorDot> decor,
  })
  _layout(double width, int unlocked) {
    final amplitude = (width - _tileSize) / 2 - 4;
    final centerX = width / 2;
    final centers = <Offset>[];
    final bannerTops = <double>[];
    final rnd = math.Random(7331);
    var y = 0.0;
    var angle1 = 0.0;
    var angle2 = 0.0;
    var freq1 = 1.8;
    var freq2 = 2.9;
    var amp = amplitude;
    var segLeft = 0;
    for (var i = 0; i < kLevelCount; i++) {
      if (i % 20 == 0) {
        bannerTops.add(y);
        y += _bannerHeight;
      }
      if (segLeft <= 0) {
        segLeft = 3 + rnd.nextInt(4);
        freq1 = 1.2 + rnd.nextDouble() * 1.3;
        freq2 = 2.0 + rnd.nextDouble() * 1.8;
        amp = amplitude * (0.55 + rnd.nextDouble() * 0.45);
      }
      segLeft--;
      angle1 += freq1;
      angle2 += freq2;
      final wave = 0.6 * math.sin(angle1) + 0.4 * math.sin(angle2);
      final rowStep =
          _minRowStep + rnd.nextDouble() * (_maxRowStep - _minRowStep);
      centers.add(Offset(centerX + amp * wave, y + rowStep / 2));
      y += rowStep;
    }
    return (
      centers: centers,
      bannerTops: bannerTops,
      totalHeight: y,
      segments: _buildSegments(centers, unlocked),
      decor: _buildDecor(width, y, centers, bannerTops),
    );
  }

  /// Rải hạt lấp lánh trang trí (không bấm được) khắp vùng nền còn trống
  /// quanh path, seed cố định để ổn định giữa các lần build. Loại bỏ điểm
  /// quá gần tile hoặc đè lên dải banner để không che nội dung tương tác.
  List<_DecorDot> _buildDecor(
    double width,
    double totalHeight,
    List<Offset> centers,
    List<double> bannerTops,
  ) {
    final rnd = math.Random(4242);
    final count = (width * totalHeight / 7000).round();
    final minDist = _tileSize * 0.8;
    final decor = <_DecorDot>[];
    for (var n = 0; n < count; n++) {
      final p = Offset(
        rnd.nextDouble() * width,
        rnd.nextDouble() * totalHeight,
      );
      var blocked = false;
      for (final c in centers) {
        if ((p - c).distanceSquared < minDist * minDist) {
          blocked = true;
          break;
        }
      }
      if (!blocked) {
        for (final bt in bannerTops) {
          if (p.dy >= bt - 6 && p.dy <= bt + _bannerHeight + 6) {
            blocked = true;
            break;
          }
        }
      }
      if (blocked) continue;
      decor.add(
        _DecorDot(
          pos: p,
          size: 3 + rnd.nextDouble() * 5,
          plus: rnd.nextBool(),
          phase: rnd.nextDouble() * math.pi * 2,
        ),
      );
    }
    return decor;
  }

  /// Mỗi đoạn nối 2 node liên tiếp thành 1 [_PathSegment] riêng: đường cong
  /// Catmull-Rom lệch ngẫu nhiên nhẹ (seed cố định theo index → ổn định giữa
  /// các lần build) cho cảm giác đường mòn tự nhiên, tô màu theo world của
  /// node đích, kèm sẵn danh sách điểm hạt (bead) cách đều dọc đoạn.
  List<_PathSegment> _buildSegments(List<Offset> centers, int unlocked) {
    final segments = <_PathSegment>[];
    for (var i = 0; i < centers.length - 1; i++) {
      final p0 = i == 0 ? centers[i] : centers[i - 1];
      final p1 = centers[i];
      final p2 = centers[i + 1];
      final p3 = i + 2 < centers.length ? centers[i + 2] : p2;
      var cp1 = p1 + (p2 - p0) / 4;
      var cp2 = p2 - (p3 - p1) / 4;

      final dir = p2 - p1;
      final dirLen = dir.distance;
      if (dirLen > 0) {
        final normal = Offset(-dir.dy, dir.dx) / dirLen;
        final wiggle = (math.Random(i).nextDouble() - 0.5) * 32;
        cp1 += normal * wiggle;
        cp2 += normal * wiggle;
      }

      final segPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
      final metric = segPath.computeMetrics().first;
      // Đoạn dẫn tới node (i+2) đã unlock → "lit": sáng gold, bead dày hơn.
      final lit = (i + 2) <= unlocked;

      final dots = <Offset>[];
      final step = lit ? 12.0 : 20.0;
      for (var d = step; d < metric.length; d += step) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent != null) dots.add(tangent.position);
      }

      segments.add(
        _PathSegment(
          path: segPath,
          metric: metric,
          color: worldForLevel(i + 2).color,
          dots: dots,
          lit: lit,
        ),
      );
    }
    return segments;
  }

  void _autoScrollTo(
    int unlockedId,
    List<Offset> centers,
    double viewportH,
    double totalHeight,
  ) {
    if (_scrolled) return;
    _scrolled = true;
    final targetY = centers[(unlockedId - 1).clamp(0, centers.length - 1)].dy;
    final maxExtent = math.max(0.0, totalHeight - viewportH);
    final offset = (targetY - viewportH / 2).clamp(0.0, maxExtent);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.jumpTo(offset),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    // Vừa unlock 1 màn trong lúc màn hình này bị GameScreen che — chỉ chạy
    // reveal animation khi đã quay lại và đây thực sự là route đang hiện.
    if (_pendingReveal != null && (ModalRoute.of(context)?.isCurrent ?? true)) {
      final id = _pendingReveal!;
      _pendingReveal = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _playReveal(id));
    }
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'select_level'.tr,
                color: NeonTheme.cyan,
                actions: [
                  PrestigeAction(
                    gameCtrl: gameCtrl,
                    onTap: () => showPrestigeDialog(context, gameCtrl),
                  ),
                  CoinChip(gameCtrl),
                ],
              ),
              Expanded(
                child: Obx(() {
                  final unlocked = gameCtrl.unlockedLevel.value;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final layout = _layout(constraints.maxWidth, unlocked);
                      _autoScrollTo(
                        unlocked,
                        layout.centers,
                        constraints.maxHeight,
                        layout.totalHeight,
                      );
                      return Stack(
                        children: [
                          // Lớp decor sparkle: parallax — trôi chậm hơn
                          // path/tile khi cuộn, tạo cảm giác chiều sâu.
                          Positioned.fill(
                            child: ClipRect(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _scrollController,
                                    _flowCtrl,
                                  ]),
                                  builder: (context, _) => CustomPaint(
                                    painter: _DecorPainter(
                                      layout.decor,
                                      _throttledFlow,
                                      scrollOffset: _scrollController.hasClients
                                          ? _scrollController.offset
                                          : 0.0,
                                      parallax: 0.55,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: layout.totalHeight,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: AnimatedBuilder(
                                          animation: Listenable.merge([
                                            _flowCtrl,
                                            _revealCtrl,
                                          ]),
                                          builder: (context, _) => CustomPaint(
                                            painter: _PathPainter(
                                              layout.segments,
                                              _throttledFlow,
                                              revealId: _revealId,
                                              revealProgress: _revealCtrl.value,
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (var w = 0; w < kWorlds.length; w++)
                                        Positioned(
                                          top: layout.bannerTops[w],
                                          left: 0,
                                          right: 0,
                                          height: _bannerHeight,
                                          child: _WorldBanner(
                                            world: kWorlds[w],
                                          ),
                                        ),
                                      for (var i = 0; i < kLevelCount; i++)
                                        Positioned(
                                          left:
                                              layout.centers[i].dx -
                                              _tileSize / 2,
                                          top:
                                              layout.centers[i].dy -
                                              _tileSize / 2,
                                          width: _tileSize,
                                          height: _tileSize,
                                          child: _buildTile(
                                            gameCtrl,
                                            i + 1,
                                            unlocked,
                                          ),
                                        ),
                                      Positioned(
                                        left:
                                            layout.centers[unlocked - 1].dx -
                                            14,
                                        top:
                                            layout.centers[unlocked - 1].dy -
                                            _tileSize / 2 -
                                            34,
                                        child: const _Mascot(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Positioned.fill(child: _ShootingStar()),
                          if (_showConfetti)
                            const Positioned.fill(child: ConfettiOverlay()),
                        ],
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(GameController gameCtrl, int id, int unlocked) {
    final locked = id > unlocked;
    final current = id == unlocked;
    final stars = StorageService.to.getInt(StorageKeys.star(id));
    final tile = _LevelTile(
      id: id,
      locked: locked,
      stars: stars,
      isBoss: kLevels[id - 1].isBoss,
      onTap: locked
          ? null
          : () {
              gameCtrl.startLevel(id);
              Get.to(() => const GameScreen());
            },
      onLongPress: (!locked && stars > 0)
          ? () => _showPerfectClearDialog(gameCtrl, id)
          : null,
    );
    return current ? _Pulse(child: tile) : tile;
  }

  /// Task #5: thử thách chơi lại — vượt best score hiện tại để nhận bonus
  /// coin, mở qua long-press trên level đã qua (giữ tap ngắn = chơi bình
  /// thường như trước, không phá hành vi cũ).
  void _showPerfectClearDialog(GameController gameCtrl, int id) {
    final best = StorageService.to.getInt(StorageKeys.highScore(id));
    NeonDialog.show(
      context: context,
      title: 'perfect_clear_title'.tr,
      color: NeonTheme.gold,
      icon: Icons.emoji_events_rounded,
      message: 'perfect_clear_msg'.trParams({
        'score': '$best',
        'coin': '${GameController.perfectClearBonusCoins}',
      }),
      actions: [
        NeonDialogAction(
          label: 'cancel'.tr,
          color: NeonTheme.cyan,
          onTap: () {},
        ),
        NeonDialogAction(
          label: 'perfect_clear_start'.tr,
          color: NeonTheme.gold,
          onTap: () {
            gameCtrl.startPerfectClear(id);
            Get.to(() => const GameScreen());
          },
        ),
      ],
    );
  }
}

/// 1 đoạn cong nối 2 node liên tiếp, đã dựng sẵn hình học (path + metric +
/// vị trí hạt) trong `_layout` — mỗi frame animate chỉ vẽ lại, không tính
/// toán lại Catmull-Rom/wiggle.
class _DecorDot {
  final Offset pos;
  final double size;
  final bool plus;
  final double phase;
  _DecorDot({
    required this.pos,
    required this.size,
    required this.plus,
    required this.phase,
  });
}

/// Vẽ hạt lấp lánh trang trí tĩnh (chỉ nhấp nháy độ mờ theo [progress]) rải
/// khắp nền quanh path — lấp bớt khoảng trống, không tương tác.
class _DecorPainter extends CustomPainter {
  final List<_DecorDot> dots;
  final double progress;
  final double scrollOffset;
  final double parallax;
  _DecorPainter(
    this.dots,
    this.progress, {
    this.scrollOffset = 0,
    this.parallax = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(0, -(scrollOffset * parallax));
    final tau = progress * math.pi * 2;
    for (final d in dots) {
      final tw = 0.5 + 0.5 * math.sin(tau + d.phase);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25 + 0.35 * tw);
      if (d.plus) {
        canvas.drawLine(
          d.pos.translate(-d.size, 0),
          d.pos.translate(d.size, 0),
          paint..strokeWidth = 1.4,
        );
        canvas.drawLine(
          d.pos.translate(0, -d.size),
          d.pos.translate(0, d.size),
          paint..strokeWidth = 1.4,
        );
      } else {
        canvas.drawCircle(d.pos, d.size * 0.5, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DecorPainter old) =>
      old.progress != progress ||
      old.dots != dots ||
      old.scrollOffset != scrollOffset;
}

class _PathSegment {
  final Path path;
  final PathMetric metric;
  final Color color;
  final List<Offset> dots;
  final bool lit;
  _PathSegment({
    required this.path,
    required this.metric,
    required this.color,
    required this.dots,
    required this.lit,
  });
}

/// Vẽ toàn tuyến đường: mỗi [_PathSegment] tô glow + core theo màu world
/// riêng, rắc hạt (bead) cách đều dọc đoạn, và chạy 1 dải sáng trắng lướt
/// dọc đoạn theo [progress] (0..1, lặp vô hạn) để tạo cảm giác năng lượng
/// đang chảy trên đường.
class _PathPainter extends CustomPainter {
  final List<_PathSegment> segments;
  final double progress;
  final int? revealId;
  final double revealProgress;
  _PathPainter(
    this.segments,
    this.progress, {
    this.revealId,
    this.revealProgress = 0,
  });

  static const _dashLen = 26.0;
  static const _dashGap = 40.0;
  static const _cycle = _dashLen + _dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final flowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final baseColor = seg.lit
          ? Color.lerp(seg.color, NeonTheme.gold, 0.55)!
          : Color.lerp(seg.color, Colors.grey, 0.6)!;
      final glowPaint = Paint()
        ..color = baseColor.withValues(alpha: seg.lit ? 0.45 : 0.15)
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final corePaint = Paint()
        ..color = baseColor.withValues(alpha: seg.lit ? 0.9 : 0.35)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(seg.path, glowPaint);
      canvas.drawPath(seg.path, corePaint);

      for (final dot in seg.dots) {
        canvas.drawCircle(
          dot,
          3.5,
          Paint()..color = Colors.white.withValues(alpha: seg.lit ? 0.85 : 0.3),
        );
      }

      if (seg.lit) {
        var start = (progress * _cycle) % _cycle - _dashLen;
        while (start < seg.metric.length) {
          final clampedStart = start.clamp(0.0, seg.metric.length);
          final end = (start + _dashLen).clamp(0.0, seg.metric.length);
          if (end > clampedStart) {
            canvas.drawPath(
              seg.metric.extractPath(clampedStart, end),
              flowPaint,
            );
          }
          start += _cycle;
        }
      }

      // Unlock reveal: đoạn dẫn tới node vừa mở khoá — ánh sáng chạy dọc
      // đoạn 1 lần theo revealProgress (0..1).
      if (revealId != null && i + 2 == revealId && revealProgress > 0) {
        final end = (revealProgress * seg.metric.length).clamp(
          0.0,
          seg.metric.length,
        );
        if (end > 0) {
          canvas.drawPath(
            seg.metric.extractPath(0, end),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.95)
              ..strokeWidth = 9
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.progress != progress ||
      oldDelegate.revealId != revealId ||
      oldDelegate.revealProgress != revealProgress;
}

class _WorldBanner extends StatelessWidget {
  final GameWorld world;
  const _WorldBanner({required this.world});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: NeonTheme.s8,
      ),
      decoration: BoxDecoration(
        color: world.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: NeonTheme.drop(y: 3, blur: 6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (i) => Transform.rotate(
                      angle: (i.isEven ? -1 : 1) * 0.3,
                      child: Icon(world.icon, size: 34, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            // I81: tên vùng + luật thời tiết phải nằm trong `Column` RIÊNG.
            // `Stack` bên ngoài là để lớp hoạ tiết chạy nền phía sau chữ; thả
            // thêm một child vào đó là nó vẽ **đè lên** tên vùng — đã thấy tận
            // mắt trên máy trước khi sửa.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StrokeText(world.nameKey.tr, fontSize: 18),
                // Luật vô hình = luật không tồn tại, nên hiện ngay dưới tên
                // vùng. World không có luật thì không dựng gì.
                if (kWeatherRules[world.weather] case final rule?)
                  Padding(
                    key: Key('world_rule_${world.startId}'),
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'weather_rule_banner'.trParams({'rule': rule.descKey.tr}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bọc node hiện tại (màn cao nhất mở khoá) bằng hiệu ứng pulse nhẹ.
class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) =>
          Transform.scale(scale: 1 + _ctrl.value * 0.1, child: child),
      child: widget.child,
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int id;
  final bool locked;
  final int stars;
  final bool isBoss;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _LevelTile({
    required this.id,
    required this.locked,
    required this.stars,
    required this.isBoss,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = locked
        ? NeonTheme.lockedBorder
        : (isBoss ? NeonTheme.gold : NeonTheme.cyan);
    return Semantics(
      button: true,
      enabled: !locked,
      label: locked ? 'Level $id, locked' : 'Level $id',
      child: GestureDetector(
        key: Key('level_tile_$id'),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: locked ? NeonTheme.lockedFill : NeonTheme.card,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isBoss ? 4 : 3),
            boxShadow: locked ? null : NeonTheme.drop(y: 4, blur: 8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (locked)
                    const Icon(
                      Icons.lock_rounded,
                      color: NeonTheme.lockedBorder,
                      size: 20,
                    )
                  else
                    Text(
                      '$id',
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (!locked && stars > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (s) => Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: s < stars
                              ? NeonTheme.gold
                              : NeonTheme.ink.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                ],
              ),
              // F11: node boss (cuối mỗi world) — vương miện góc trên phân biệt
              // với node thường trên path map, kể cả khi chưa mở khoá.
              if (isBoss)
                Positioned(
                  top: -4,
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 18,
                    color: locked ? NeonTheme.lockedBorder : NeonTheme.gold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mascot đứng tại node hiện tại, nhún nhẹ liên tục (idle bounce).
class _Mascot extends StatefulWidget {
  const _Mascot();

  @override
  State<_Mascot> createState() => _MascotState();
}

class _MascotState extends State<_Mascot> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -6 * _ctrl.value),
          child: child,
        ),
        child: const Text('⭐', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}

/// Sao băng bay ngẫu nhiên qua nền, tạo cảm giác nền có sự sống.
class _ShootingStar extends StatefulWidget {
  const _ShootingStar();

  @override
  State<_ShootingStar> createState() => _ShootingStarState();
}

class _ShootingStarState extends State<_ShootingStar>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final _rng = math.Random();
  Timer? _timer;
  Offset _start = Offset.zero;
  Offset _end = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    final wait = Duration(seconds: 6 + _rng.nextInt(9));
    _timer = Timer(wait, _fly);
  }

  void _fly() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final startX = size.width * (0.15 + _rng.nextDouble() * 0.5);
    _start = Offset(startX, 0);
    _end = Offset(startX - size.width * 0.28, size.height * 0.32);
    _ctrl.forward(from: 0).then((_) {
      if (mounted) _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _CometPainter(_start, _end, _ctrl.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _CometPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double progress;
  _CometPainter(this.start, this.end, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final head = Offset.lerp(start, end, progress)!;
    final tailProgress = (progress - 0.18).clamp(0.0, 1.0);
    final tail = Offset.lerp(start, end, tailProgress)!;
    final fade = 1 - progress;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * fade)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(tail, head, linePaint);

    final headPaint = Paint()
      ..color = Colors.white.withValues(alpha: fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(head, 3, headPaint);
  }

  @override
  bool shouldRepaint(covariant _CometPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.start != start ||
      oldDelegate.end != end;
}
