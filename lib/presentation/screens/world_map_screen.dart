import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../../data/story.dart';
import '../controllers/game_controller.dart';
import '../controllers/pregame_controller.dart';
import '../controllers/story_controller.dart';
import '../../core/utils/format.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/story_overlay.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';

/// Bản đồ hành trình node-based: đường đi uốn lượn nối 100 màn, gom theo
/// thế giới, node hiện tại pulse — phong cách Candy Crush, nền động lung linh.
class WorldMapScreen extends StatelessWidget {
  const WorldMapScreen({super.key});

  static const double _vGap = 96; // khoảng cách dọc giữa 2 node (nhỏ gọn)
  static const double _topPad = 92; // chừa chỗ cho banner thế giới đầu tiên
  static const double _nodeSize = 46; // node nhỏ lại

  /// Màu thế giới — nguồn duy nhất ở [NeonTheme.accentForWorld].
  static Color worldColor(int w) => NeonTheme.accentForWorld(w);

  /// X tương đối (0..1) của node theo chỉ số (zig-zag mềm bằng sin).
  static double fx(int i) => 0.5 + 0.27 * math.sin(i * 0.9);

  void _play(GameController ctrl, int index) {
    if (!ctrl.hasLife) {
      final ctx = Get.context;
      if (ctx != null) {
        final next = ctrl.timeToNextLife;
        final msg = next > Duration.zero
            ? '${'lives_none_msg'.tr} (${fmtDur(next)})'
            : 'lives_none_msg'.tr;
        ScaffoldMessenger.of(ctx)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(msg,
                style: const TextStyle(fontFamily: 'Baloo2', fontSize: 13)),
            backgroundColor: NeonTheme.panel,
            behavior: SnackBarBehavior.floating,
          ));
      }
      return;
    }
    final t = storyStartTriggerFor(index);
    if (t != null &&
        StoryController.to.maybeShow(t, worldOfLevel(index).index,
            onComplete: () => _afterStory(ctrl, index))) {
      return;
    }
    _afterStory(ctrl, index);
  }

  void _afterStory(GameController ctrl, int index) {
    final pg = Get.find<PregameController>();
    if (pg.hasAny) {
      pg.openFor(index);
    } else {
      ctrl.startLevel(index);
      Get.to(() => const GameScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<GameController>();
    final pg = Get.put(PregameController(ctrl));
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  NeonAppBar(
                    title: 'world_map'.tr,
                    color: NeonTheme.cyan,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.grid_view_rounded,
                            color: NeonTheme.cyan),
                        tooltip: 'grid_view'.tr,
                        onPressed: () {
                          // chủ động đổi style → lưu local (grid)
                          StorageService.to.setInt(StorageKeys.viewMode, 1);
                          Get.off(() => const LevelSelectScreen());
                        },
                      ),
                      CoinChip(ctrl),
                    ],
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) => Obx(() {
                        final current =
                            ctrl.unlockedLevel.value.clamp(1, kLevels.length);
                        ctrl.stars.length; // observe
                        return _AnimatedMap(
                          ctrl: ctrl,
                          width: c.maxWidth,
                          current: current,
                          vGap: _vGap,
                          topPad: _topPad,
                          nodeSize: _nodeSize,
                          onPlay: (i) => _play(ctrl, i),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              Obx(() => pg.open.value
                  ? _pregameOverlay(ctrl, pg)
                  : const SizedBox.shrink()),
              const StoryOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pregameOverlay(GameController ctrl, PregameController pg) {
    return NeonDialog.overlay(
      onBarrier: pg.close,
      panel: NeonDialog.panel(
        title: 'pregame_title'.tr,
        color: NeonTheme.lime,
        icon: Icons.rocket_launch_rounded,
        message: 'pregame_msg'.tr,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => _pgOption(Icons.av_timer_rounded, NeonTheme.lime,
                'pregame_moves'.tr, ctrl.boosterMoves.value,
                pg.useMoves.value, pg.toggleMoves)),
            const SizedBox(height: NeonTheme.s8),
            Obx(() => _pgOption(Icons.gavel_rounded, NeonTheme.orange,
                'pregame_hammer'.tr, ctrl.boosterHammer.value,
                pg.armHammer.value, pg.toggleHammer)),
          ],
        ),
        actions: [
          NeonDialogAction(
              label: 'pregame_skip'.tr,
              color: NeonTheme.cyan,
              onTap: () {
                pg.useMoves.value = false;
                pg.armHammer.value = false;
                pg.start();
                ctrl.startLevel(pg.level.value);
                Get.to(() => const GameScreen());
              }),
          NeonDialogAction(
              label: 'play_now'.tr,
              color: NeonTheme.lime,
              onTap: () {
                pg.start();
                ctrl.startLevel(pg.level.value);
                Get.to(() => const GameScreen());
              }),
        ],
      ),
    );
  }

  Widget _pgOption(IconData icon, Color color, String label, int count,
      bool selected, VoidCallback onTap) {
    final owned = count > 0;
    return GestureDetector(
      onTap: owned ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.25)
              : NeonTheme.panel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: owned ? color : Colors.white24,
              width: selected ? 2.5 : 1.4),
          boxShadow: selected ? NeonTheme.glow(color, blur: 10) : null,
        ),
        child: Row(children: [
          Icon(icon, color: owned ? color : Colors.white38, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  color: owned ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
          ),
          Text('x$count',
              style: TextStyle(
                fontFamily: 'Baloo2',
                color: owned ? color : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(width: 6),
          Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? color : Colors.white30, size: 18),
        ]),
      ),
    );
  }
}

/// Phần cuộn của bản đồ — Stateful để chạy animation nền (sao lấp lánh,
/// xung năng lượng chạy dọc path) bằng 1 AnimationController.
class _AnimatedMap extends StatefulWidget {
  final GameController ctrl;
  final double width;
  final int current;
  final double vGap;
  final double topPad;
  final double nodeSize;
  final void Function(int level) onPlay;

  const _AnimatedMap({
    required this.ctrl,
    required this.width,
    required this.current,
    required this.vGap,
    required this.topPad,
    required this.nodeSize,
    required this.onPlay,
  });

  @override
  State<_AnimatedMap> createState() => _AnimatedMapState();
}

class _AnimatedMapState extends State<_AnimatedMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final List<_Star> _stars;
  late final ScrollController _scroll;

  double get _totalH => widget.topPad * 2 + kLevelCount * widget.vGap;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    final rng = math.Random(7);
    // sao lấp lánh rải đều toàn bản đồ
    _stars = List.generate(140, (i) {
      return _Star(
        pos: Offset(rng.nextDouble(), rng.nextDouble() * _totalH),
        phase: rng.nextDouble(),
        size: 0.8 + rng.nextDouble() * 2.0,
        color: WorldMapScreen.worldColor(rng.nextInt(5) + 1),
      );
    });
    _scroll = ScrollController();
    // cuộn tới gần node hiện tại sau frame đầu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final y = widget.topPad + (widget.current - 1) * widget.vGap;
      final target = (y - 220).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centers = List<Offset>.generate(kLevelCount, (i) {
      return Offset(widget.width * WorldMapScreen.fx(i),
          widget.topPad + i * widget.vGap);
    });
    return SingleChildScrollView(
      controller: _scroll,
      child: SizedBox(
        width: widget.width,
        height: _totalH,
        child: Stack(
          children: [
            // nền động: sao lấp lánh + path + xung năng lượng
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, _) => CustomPaint(
                  painter: _MapPainter(
                    centers: centers,
                    current: widget.current,
                    t: _anim.value,
                    stars: _stars,
                    width: widget.width,
                  ),
                ),
              ),
            ),
            // banner thế giới
            for (final w in kWorlds)
              Positioned(
                left: 0,
                right: 0,
                top: widget.topPad + (w.startLevel - 1) * widget.vGap - 56,
                child: Center(child: _worldBadge(w)),
              ),
            // node từng màn
            for (int i = 0; i < kLevelCount; i++)
              Positioned(
                left: centers[i].dx - widget.nodeSize / 2,
                top: centers[i].dy - widget.nodeSize / 2,
                child: _node(kLevels[i], i + 1 <= widget.current,
                    i + 1 == widget.current),
              ),
          ],
        ),
      ),
    );
  }

  Widget _worldBadge(WorldConfig w) {
    final c = WorldMapScreen.worldColor(w.index);
    final reached = widget.current >= w.startLevel;
    var stars = 0;
    for (int lv = w.startLevel; lv <= w.endLevel; lv++) {
      stars += widget.ctrl.stars[lv] ?? 0;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          c.withValues(alpha: reached ? 0.32 : 0.12),
          NeonTheme.panel.withValues(alpha: 0.85),
        ]),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
            color: reached ? c : c.withValues(alpha: 0.4), width: 1.5),
        boxShadow: reached ? NeonTheme.glow(c, blur: 8) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(reached ? Icons.public_rounded : Icons.lock_rounded,
            color: reached ? c : Colors.white38, size: 14),
        const SizedBox(width: 6),
        Text(
          '${'world_n'.trParams({'n': '${w.index}'})} · ${worldNameKey(w.index).tr}',
          style: TextStyle(
            fontFamily: 'Baloo2',
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: c, blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 7),
        const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
        const SizedBox(width: 2),
        Text('$stars',
            style: const TextStyle(
              fontFamily: 'Baloo2',
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            )),
      ]),
    );
  }

  Widget _node(LevelConfig lv, bool unlocked, bool isCurrent) {
    final size = widget.nodeSize;
    final c = unlocked
        ? WorldMapScreen.worldColor(((lv.index - 1) ~/ kWorldSize) + 1)
        : Colors.grey.shade700;
    final star = widget.ctrl.stars[lv.index] ?? 0;
    final core = GestureDetector(
      onTap: unlocked ? () => widget.onPlay(lv.index) : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: unlocked
              ? RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [
                    Color.lerp(c, Colors.white, 0.55)!,
                    c,
                    Color.lerp(c, Colors.black, 0.3)!,
                  ],
                )
              : null,
          color: unlocked ? null : NeonTheme.panel.withValues(alpha: 0.6),
          border: Border.all(
              color: isCurrent ? Colors.white : c, width: isCurrent ? 2.5 : 1.6),
          boxShadow: unlocked ? NeonTheme.glow(c, blur: isCurrent ? 14 : 8) : null,
        ),
        alignment: Alignment.center,
        child: unlocked
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${lv.index}',
                      style: const TextStyle(
                        fontFamily: 'Baloo2',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      )),
                  if (star > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (s) => Icon(Icons.star_rounded,
                            size: 6,
                            color: s < star ? Colors.amber : Colors.white24),
                      ),
                    ),
                ],
              )
            : Icon(Icons.lock_rounded, color: Colors.white38, size: size * 0.4),
      ),
    );
    if (!isCurrent) return core;
    // node hiện tại: vầng sáng xoay + pulse + chấm "bạn đang ở đây"
    return SizedBox(
      width: size + 26,
      height: size + 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 22,
            height: size + 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: [
                c.withValues(alpha: 0),
                c.withValues(alpha: 0.7),
                Colors.white.withValues(alpha: 0.9),
                c.withValues(alpha: 0.7),
                c.withValues(alpha: 0),
              ]),
            ),
          )
              .animate(onPlay: (a) => a.repeat())
              .rotate(duration: 2400.ms),
          core
              .animate(onPlay: (a) => a.repeat(reverse: true))
              .scaleXY(
                  begin: 1, end: 1.12, duration: 760.ms, curve: Curves.easeInOut),
        ],
      ),
    );
  }
}

class _Star {
  final Offset pos; // x: 0..1, y: pixel
  final double phase;
  final double size;
  final Color color;
  const _Star(
      {required this.pos,
      required this.phase,
      required this.size,
      required this.color});
}

/// Vẽ nền động: sao lấp lánh + đường path (sáng tới màn đã đi, mờ tới khoá)
/// + các xung năng lượng chạy dọc path về phía node hiện tại.
class _MapPainter extends CustomPainter {
  final List<Offset> centers;
  final int current;
  final double t; // 0..1 lặp
  final List<_Star> stars;
  final double width;

  _MapPainter({
    required this.centers,
    required this.current,
    required this.t,
    required this.stars,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1) sao lấp lánh
    for (final s in stars) {
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin((t + s.phase) * math.pi * 2));
      final p = Offset(s.pos.dx * width, s.pos.dy);
      canvas.drawCircle(
        p,
        s.size,
        Paint()
          ..color = s.color.withValues(alpha: 0.25 + 0.55 * tw)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
    if (centers.length < 2) return;

    // 2) đường path: base mờ + đoạn đã đi sáng
    for (var i = 0; i < centers.length - 1; i++) {
      final reached = (i + 1) < current;
      _segment(canvas, centers[i], centers[i + 1],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = reached ? 8 : 6
            ..strokeCap = StrokeCap.round
            ..color = reached
                ? NeonTheme.cyan.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.10));
      if (reached) {
        // lõi sáng mảnh
        _segment(canvas, centers[i], centers[i + 1],
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.5));
      }
    }

    // 3) xung năng lượng chạy dọc đoạn đã đi (3 xung lệch pha)
    final reachedSegs = (current - 1).clamp(0, centers.length - 1);
    if (reachedSegs >= 1) {
      for (var k = 0; k < 3; k++) {
        final frac = ((t + k / 3) % 1) * reachedSegs;
        final seg = frac.floor().clamp(0, reachedSegs - 1);
        final local = frac - seg;
        final pos = Offset.lerp(centers[seg], centers[seg + 1], local)!;
        canvas.drawCircle(
          pos,
          5,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawCircle(
          pos,
          9,
          Paint()
            ..color = NeonTheme.cyan.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
  }

  void _segment(Canvas canvas, Offset a, Offset b, Paint paint) {
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(a.dx, mid.dy, mid.dx, mid.dy)
      ..quadraticBezierTo(b.dx, mid.dy, b.dx, b.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.t != t || old.current != current;
}
