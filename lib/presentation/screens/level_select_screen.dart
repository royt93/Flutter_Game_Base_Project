import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../../data/worlds.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
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
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  bool _scrolled = false;
  late final _flowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _scrollController.dispose();
    _flowCtrl.dispose();
    super.dispose();
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
  _layout(double width) {
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
      segments: _buildSegments(centers),
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
  List<_PathSegment> _buildSegments(List<Offset> centers) {
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

      final dots = <Offset>[];
      for (var d = 20.0; d < metric.length; d += 20.0) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent != null) dots.add(tangent.position);
      }

      segments.add(
        _PathSegment(
          path: segPath,
          metric: metric,
          color: worldForLevel(i + 2).color,
          dots: dots,
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
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'Select Level',
                color: NeonTheme.cyan,
                actions: [CoinChip(gameCtrl)],
              ),
              Expanded(
                child: Obx(() {
                  final unlocked = gameCtrl.unlockedLevel.value;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final layout = _layout(constraints.maxWidth);
                      _autoScrollTo(
                        unlocked,
                        layout.centers,
                        constraints.maxHeight,
                        layout.totalHeight,
                      );
                      return CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: layout.totalHeight,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: _flowCtrl,
                                      builder: (context, _) => CustomPaint(
                                        painter: _DecorPainter(
                                          layout.decor,
                                          _flowCtrl.value,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: _flowCtrl,
                                      builder: (context, _) => CustomPaint(
                                        painter: _PathPainter(
                                          layout.segments,
                                          _flowCtrl.value,
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
                                      child: _WorldBanner(world: kWorlds[w]),
                                    ),
                                  for (var i = 0; i < kLevelCount; i++)
                                    Positioned(
                                      left:
                                          layout.centers[i].dx - _tileSize / 2,
                                      top: layout.centers[i].dy - _tileSize / 2,
                                      width: _tileSize,
                                      height: _tileSize,
                                      child: _buildTile(
                                        gameCtrl,
                                        i + 1,
                                        unlocked,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
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
      onTap: locked
          ? null
          : () {
              gameCtrl.startLevel(id);
              Get.to(() => const GameScreen());
            },
    );
    return current ? _Pulse(child: tile) : tile;
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
  _DecorPainter(this.dots, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
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
  }

  @override
  bool shouldRepaint(covariant _DecorPainter old) =>
      old.progress != progress || old.dots != dots;
}

class _PathSegment {
  final Path path;
  final PathMetric metric;
  final Color color;
  final List<Offset> dots;
  _PathSegment({
    required this.path,
    required this.metric,
    required this.color,
    required this.dots,
  });
}

/// Vẽ toàn tuyến đường: mỗi [_PathSegment] tô glow + core theo màu world
/// riêng, rắc hạt (bead) cách đều dọc đoạn, và chạy 1 dải sáng trắng lướt
/// dọc đoạn theo [progress] (0..1, lặp vô hạn) để tạo cảm giác năng lượng
/// đang chảy trên đường.
class _PathPainter extends CustomPainter {
  final List<_PathSegment> segments;
  final double progress;
  _PathPainter(this.segments, this.progress);

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

    for (final seg in segments) {
      final glowPaint = Paint()
        ..color = seg.color.withValues(alpha: 0.45)
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final corePaint = Paint()
        ..color = seg.color.withValues(alpha: 0.9)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(seg.path, glowPaint);
      canvas.drawPath(seg.path, corePaint);

      for (final dot in seg.dots) {
        canvas.drawCircle(
          dot,
          3.5,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      }

      var start = (progress * _cycle) % _cycle - _dashLen;
      while (start < seg.metric.length) {
        final clampedStart = start.clamp(0.0, seg.metric.length);
        final end = (start + _dashLen).clamp(0.0, seg.metric.length);
        if (end > clampedStart) {
          canvas.drawPath(seg.metric.extractPath(clampedStart, end), flowPaint);
        }
        start += _cycle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.progress != progress;
}

class _WorldBanner extends StatelessWidget {
  final GameWorld world;
  const _WorldBanner({required this.world});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: 4,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: world.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: NeonTheme.drop(y: 3, blur: 6),
      ),
      child: StrokeText(world.nameKey.tr, fontSize: 18),
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
  final VoidCallback? onTap;

  const _LevelTile({
    required this.id,
    required this.locked,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = locked ? const Color(0xFFBFC7D6) : NeonTheme.cyan;
    return GestureDetector(
      key: Key('level_tile_$id'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFEDEAF5) : NeonTheme.card,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          boxShadow: locked ? null : NeonTheme.drop(y: 4, blur: 8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              const Icon(Icons.lock_rounded, color: Color(0xFF9AA0B5), size: 20)
            else
              Text(
                '$id',
                style: const TextStyle(
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
      ),
    );
  }
}
