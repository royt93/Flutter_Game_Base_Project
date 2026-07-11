import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_info.dart';
import '../../core/neon_theme.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_icon.dart';
import '../widgets/star_mascot.dart';
import '../widgets/stroke_text.dart';
import 'guide_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

/// Màn hình chính: logo, nút Play, và lối vào Shop/Guide/Settings.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  child: CoinChip(gameCtrl),
                ),
              ),
              const Spacer(flex: 2),
              const StarMascot(size: 128),
              const SizedBox(height: NeonTheme.s16),
              StrokeText(
                kAppName,
                fontSize: 46,
                color: Colors.white,
                stroke: NeonTheme.magenta,
                strokeWidth: 6,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: NeonTheme.purple.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              const Spacer(flex: 3),
              NeonButton(
                label: 'PLAY',
                color: NeonTheme.cyan,
                icon: Icons.play_arrow_rounded,
                onTap: () => Get.to(() => const LevelSelectScreen()),
              ),
              const SizedBox(height: NeonTheme.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NeonIconButton(
                    Icons.storefront_rounded,
                    color: NeonTheme.yellow,
                    size: 28,
                    boxed: true,
                    onTap: () => Get.to(() => const ShopScreen()),
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.menu_book_rounded,
                    color: NeonTheme.lime,
                    size: 28,
                    boxed: true,
                    onTap: () => Get.to(() => const GuideScreen()),
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.settings_rounded,
                    color: NeonTheme.purple,
                    size: 28,
                    boxed: true,
                    onTap: () => Get.to(() => const SettingsScreen()),
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: NeonTheme.s16),
                child: Text(
                  kCopyright,
                  style: TextStyle(
                    color: NeonTheme.ink.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
