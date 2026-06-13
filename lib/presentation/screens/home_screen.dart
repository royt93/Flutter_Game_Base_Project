import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../core/app_info.dart';
import '../../core/neon_theme.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import 'guide_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(GameController(), permanent: true);
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s24, vertical: NeonTheme.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GemSparkle(),
                  const SizedBox(height: NeonTheme.s24),
                  Text(
                    'NEON',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 6,
                      shadows: NeonTheme.gemColors
                          .take(3)
                          .map((c) => Shadow(color: c, blurRadius: 24))
                          .toList(),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .shimmer(duration: 2200.ms, color: NeonTheme.cyan)
                      .scaleXY(begin: 1, end: 1.04, duration: 1600.ms),
                  const Text(
                    'JEWELS',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: NeonTheme.magenta,
                      letterSpacing: 10,
                      shadows: [Shadow(color: NeonTheme.magenta, blurRadius: 28)],
                    ),
                  ),
                  const SizedBox(height: NeonTheme.s24 * 1.5),
                  NeonButton(
                    label: 'play_now'.tr,
                    color: NeonTheme.lime,
                    icon: Icons.play_arrow_rounded,
                    onTap: () => Get.to(() => const LevelSelectScreen()),
                  ),
                  const SizedBox(height: NeonTheme.s16),
                  NeonButton(
                    label: 'quick_level1'.tr,
                    color: NeonTheme.cyan,
                    icon: Icons.bolt,
                    onTap: () {
                      Get.find<GameController>().startLevel(1);
                      Get.to(() => const LevelSelectScreen());
                    },
                  ),
                  const SizedBox(height: NeonTheme.s16),
                  NeonButton(
                    label: 'guide'.tr,
                    color: NeonTheme.magenta,
                    icon: Icons.menu_book_rounded,
                    onTap: () => Get.to(() => const GuideScreen()),
                  ),
                  const SizedBox(height: NeonTheme.s16),
                  NeonButton(
                    label: 'settings'.tr,
                    color: NeonTheme.purple,
                    icon: Icons.settings,
                    onTap: () => Get.to(() => const SettingsScreen()),
                  ),
                  const SizedBox(height: NeonTheme.s24),
                  Text(
                    'v$kAppVersion',
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: NeonTheme.cyan, blurRadius: 12),
                        Shadow(color: NeonTheme.cyan, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: NeonTheme.s8),
                  Text(
                    kCopyright,
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(color: NeonTheme.magenta, blurRadius: 12),
                        Shadow(color: NeonTheme.magenta, blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cụm gem nhỏ lấp lánh trên logo.
class _GemSparkle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        for (int i = 0; i < 5; i++)
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: NeonTheme.gemColors[i],
              borderRadius: BorderRadius.circular(8),
              boxShadow: NeonTheme.glow(NeonTheme.gemColors[i], blur: 14),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.8, end: 1.2, duration: (800 + i * 160).ms)
              .then()
              .rotate(begin: 0, end: 0.04),
      ],
    );
  }
}
