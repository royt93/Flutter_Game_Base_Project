import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/neon_theme.dart';
import '../../data/levels.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_button.dart';
import 'level_select_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(GameController(), permanent: true);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: NeonTheme.bgGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                _GemSparkle(),
                const SizedBox(height: 24),
                Text(
                  'NEON',
                  style: GoogleFonts.orbitron(
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
                Text(
                  'JEWELS',
                  style: GoogleFonts.orbitron(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: NeonTheme.magenta,
                    letterSpacing: 10,
                    shadows: [
                      const Shadow(color: NeonTheme.magenta, blurRadius: 28),
                    ],
                  ),
                ),
                const Spacer(),
                NeonButton(
                  label: 'CHƠI NGAY',
                  color: NeonTheme.lime,
                  icon: Icons.play_arrow_rounded,
                  onTap: () => Get.to(() => const LevelSelectScreen()),
                ),
                const SizedBox(height: 18),
                NeonButton(
                  label: 'LEVEL 1',
                  color: NeonTheme.cyan,
                  icon: Icons.bolt,
                  onTap: () {
                    Get.find<GameController>().startLevel(1);
                    Get.to(() => const LevelSelectScreen());
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  '${kLevels.length} levels · style neon',
                  style: GoogleFonts.orbitron(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
              ],
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
