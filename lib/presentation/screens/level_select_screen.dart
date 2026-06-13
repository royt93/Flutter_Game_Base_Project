import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../data/levels.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  Color _colorOf(int index) =>
      NeonTheme.gemColors[(index - 1) % NeonTheme.gemColors.length];

  IconData _objIcon(ObjectiveType o) {
    switch (o) {
      case ObjectiveType.score:
        return Icons.star_rounded;
      case ObjectiveType.collect:
        return Icons.diamond_rounded;
      case ObjectiveType.clearJelly:
        return Icons.blur_on_rounded;
    }
  }

  void _play(GameController ctrl, int index) {
    ctrl.startLevel(index);
    Get.to(() => const GameScreen());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'select_level'.tr,
                color: NeonTheme.cyan,
                actions: [_coinChip(ctrl)],
              ),
              Expanded(
                child: Obx(() {
                  final current =
                      ctrl.unlockedLevel.value.clamp(1, kLevels.length);
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(NeonTheme.s24,
                              NeonTheme.s8, NeonTheme.s24, NeonTheme.s16),
                          child: _featured(ctrl, current),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(NeonTheme.s24, 0,
                            NeonTheme.s24, NeonTheme.s24),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: NeonTheme.s8,
                            crossAxisSpacing: NeonTheme.s8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final lv = kLevels[i];
                              return _miniTile(ctrl, lv, lv.index <= current,
                                  lv.index == current);
                            },
                            childCount: kLevels.length,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coinChip(GameController ctrl) {
    return Container(
      margin: const EdgeInsets.only(right: NeonTheme.s8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NeonTheme.yellow, width: 1.5),
        boxShadow: NeonTheme.glow(NeonTheme.yellow, blur: 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded,
              color: NeonTheme.yellow, size: 18),
          const SizedBox(width: 5),
          Obx(() => Text('${ctrl.coins.value}',
              style: const TextStyle(
                fontFamily: 'Orbitron',
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ))),
        ],
      ),
    );
  }

  Widget _featured(GameController ctrl, int index) {
    final lv = kLevels[index - 1];
    final c = _colorOf(index);
    final hs = ctrl.highScores[index];
    return GestureDetector(
      onTap: () => _play(ctrl, index),
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            c.withValues(alpha: 0.25),
            NeonTheme.panel.withValues(alpha: 0.85),
          ]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c, width: 2.5),
          boxShadow: NeonTheme.glow(c, blur: 18),
        ),
        child: Row(
          children: [
            _emblem(index, c, 84),
            const SizedBox(width: NeonTheme.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('stage_n'.trParams({'n': '$index'}),
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: c, blurRadius: 12)],
                      )),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(_objIcon(lv.objective), color: c, size: 16),
                    const SizedBox(width: 6),
                    Text(hs != null ? '★ $hs' : '★ —',
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          color: Colors.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: NeonTheme.glow(c, blur: 10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 4),
                      Text('play_now'.tr,
                          style: const TextStyle(
                            fontFamily: 'Orbitron',
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          )),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (a) => a.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.015, duration: 1200.ms, curve: Curves.easeInOut);
  }

  Widget _miniTile(
      GameController ctrl, LevelConfig lv, bool unlocked, bool isCurrent) {
    final c = unlocked ? _colorOf(lv.index) : Colors.grey.shade700;
    final star = ctrl.stars[lv.index] ?? 0;
    return GestureDetector(
      onTap: unlocked ? () => _play(ctrl, lv.index) : null,
      child: Container(
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isCurrent ? Colors.white : c,
              width: isCurrent ? 2.5 : 1.6),
          boxShadow: unlocked ? NeonTheme.glow(c, blur: 7) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unlocked)
              Text('${lv.index}',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: c, blurRadius: 8)],
                  ))
            else
              const Icon(Icons.lock_rounded, color: Colors.white38, size: 18),
            if (unlocked) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (s) => Icon(
                    Icons.star_rounded,
                    size: 9,
                    color: s < star ? Colors.amber : Colors.white24,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emblem(int index, Color c, double size) {
    final light = Color.lerp(c, Colors.white, 0.5)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [light, c, Color.lerp(c, Colors.black, 0.3)!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
        boxShadow: NeonTheme.glow(c, blur: 12),
      ),
      alignment: Alignment.center,
      child: Text('$index',
          style: const TextStyle(
            fontFamily: 'Orbitron',
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
          )),
    );
  }
}
