import 'dart:math' as math;

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
const double _rowHeight = 96;
const double _bannerHeight = 60;

/// F4: 200 node xếp theo đường uốn lượn, chia 10 world (mỗi world 20 màn) có
/// banner tên + tông màu riêng. Auto-scroll tới màn cao nhất mở khoá khi vào.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final _scrollController = ScrollController();
  bool _scrolled = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Tâm node id=1..kLevelCount + top của mỗi banner world, theo chiều rộng
  /// [width] hiện có. Đường path uốn lượn dạng sóng sin quanh trục dọc giữa.
  ({List<Offset> centers, List<double> bannerTops, double totalHeight}) _layout(
    double width,
  ) {
    final amplitude = math.min(width * 0.3, (width - _tileSize) / 2 - 12);
    final centerX = width / 2;
    final centers = <Offset>[];
    final bannerTops = <double>[];
    var y = 0.0;
    for (var i = 0; i < kLevelCount; i++) {
      if (i % 20 == 0) {
        bannerTops.add(y);
        y += _bannerHeight;
      }
      final cx = centerX + amplitude * math.sin(i * math.pi / 3);
      centers.add(Offset(cx, y + _rowHeight / 2));
      y += _rowHeight;
    }
    return (centers: centers, bannerTops: bannerTops, totalHeight: y);
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
                                    child: CustomPaint(
                                      painter: _PathPainter(layout.centers),
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

class _PathPainter extends CustomPainter {
  final List<Offset> centers;
  _PathPainter(this.centers);

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    final paint = Paint()
      ..color = NeonTheme.inkSoft.withValues(alpha: 0.35)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      path.lineTo(centers[i].dx, centers[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.centers != centers;
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
          borderRadius: BorderRadius.circular(18),
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
