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

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'select_level'.tr, color: NeonTheme.cyan),
              Expanded(
                child: Obx(() => GridView.count(
                      padding: const EdgeInsets.fromLTRB(NeonTheme.s24,
                          NeonTheme.s16, NeonTheme.s24, NeonTheme.s24),
                      crossAxisCount: 2,
                      mainAxisSpacing: NeonTheme.s16,
                      crossAxisSpacing: NeonTheme.s16,
                      childAspectRatio: 0.92,
                      children: [
                        for (int i = 0; i < kLevels.length; i++)
                          _LevelTile(
                            level: kLevels[i],
                            unlocked: kLevels[i].index <= ctrl.unlockedLevel.value,
                            isCurrent: kLevels[i].index == ctrl.unlockedLevel.value,
                            highScore: ctrl.highScores[kLevels[i].index],
                            onTap: () {
                              ctrl.startLevel(kLevels[i].index);
                              Get.to(() => const GameScreen());
                            },
                          )
                              .animate()
                              .fadeIn(delay: (i * 70).ms, duration: 300.ms)
                              .slideY(begin: 0.2, curve: Curves.easeOut),
                      ],
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final LevelConfig level;
  final bool unlocked;
  final bool isCurrent;
  final int? highScore;
  final VoidCallback onTap;

  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.isCurrent,
    required this.highScore,
    required this.onTap,
  });

  Color get _color =>
      NeonTheme.gemColors[(level.index - 1) % NeonTheme.gemColors.length];

  IconData get _objIcon {
    switch (level.objective) {
      case ObjectiveType.score:
        return Icons.star_rounded;
      case ObjectiveType.collect:
        return Icons.diamond_rounded;
      case ObjectiveType.clearJelly:
        return Icons.blur_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = unlocked ? _color : Colors.grey.shade700;
    Widget tile = GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NeonTheme.panel.withValues(alpha: 0.85),
              NeonTheme.bgDark2.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c, width: 2.5),
          boxShadow: unlocked ? NeonTheme.glow(c, blur: 14) : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _emblem(c),
                const SizedBox(height: 12),
                if (unlocked)
                  _objBadge(c)
                else
                  const Icon(Icons.lock_rounded, color: Colors.white54, size: 22),
                const SizedBox(height: 8),
                Text(
                  unlocked && highScore != null ? '★ $highScore' : '— — —',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: unlocked && highScore != null
                        ? Colors.amber
                        : Colors.white24,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    shadows: unlocked && highScore != null
                        ? const [Shadow(color: Colors.amber, blurRadius: 8)]
                        : null,
                  ),
                ),
              ],
            ),
            // badge "CHƠI" cho màn hiện tại
            if (isCurrent && unlocked)
              Positioned(
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: NeonTheme.glow(c, blur: 8),
                  ),
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ),
    );

    // màn hiện tại: nhịp đập thu hút
    if (isCurrent && unlocked) {
      tile = tile
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.04, duration: 900.ms, curve: Curves.easeInOut);
    }
    return tile;
  }

  Widget _emblem(Color c) {
    final light = Color.lerp(c, Colors.white, 0.5)!;
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: unlocked
              ? [light, c, Color.lerp(c, Colors.black, 0.3)!]
              : [Colors.grey.shade600, Colors.grey.shade800],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
        boxShadow: unlocked ? NeonTheme.glow(c, blur: 10) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${level.index}',
        style: const TextStyle(
          fontFamily: 'Orbitron',
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
    );
  }

  Widget _objBadge(Color c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_objIcon, color: c, size: 16, shadows: [
          Shadow(color: c, blurRadius: 8),
        ]),
      ],
    );
  }
}
