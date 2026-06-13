import 'package:flutter/material.dart';
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
                      crossAxisCount: 3,
                      mainAxisSpacing: NeonTheme.s16,
                      crossAxisSpacing: NeonTheme.s16,
                      children: [
                        for (final lv in kLevels)
                          _LevelTile(
                            level: lv,
                            unlocked: lv.index <= ctrl.unlockedLevel.value,
                            highScore: ctrl.highScores[lv.index],
                            onTap: () {
                              ctrl.startLevel(lv.index);
                              Get.to(() => const GameScreen());
                            },
                          ),
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
  final int? highScore;
  final VoidCallback onTap;

  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.highScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = NeonTheme.gemColors[(level.index - 1) % NeonTheme.gemColors.length];
    final c = unlocked ? color : Colors.grey.shade700;
    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c, width: 2.5),
          boxShadow: unlocked ? NeonTheme.glow(c, blur: 12) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!unlocked)
              const Icon(Icons.lock, color: Colors.white54, size: 28)
            else
              Text(
                '${level.index}',
                style: TextStyle(fontFamily: 'Orbitron', 
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: c, blurRadius: 14)],
                ),
              ),
            if (unlocked && highScore != null) ...[
              const SizedBox(height: 4),
              Text(
                '★ $highScore',
                style: TextStyle(fontFamily: 'Orbitron', color: Colors.amber, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
