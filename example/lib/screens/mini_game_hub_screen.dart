import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

import 'game_demo_screen.dart';
import 'sprite_arena_demo_screen.dart';

/// Selects between the classic Flame starter and the full-screen sprite arena.
class MiniGameHubScreen extends StatelessWidget {
  const MiniGameHubScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NeonBg(
      child: SafeArea(
        child: Column(
          children: [
            NeonAppBar(title: 'mini_games_title'.tr, onBack: Get.back),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(NeonTheme.s24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'mini_games_subtitle'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: NeonTheme.inkSoft, fontSize: 16),
                      ),
                      const SizedBox(height: NeonTheme.s24),
                      CommonButton(
                        label: 'mini_game_classic_flame'.tr,
                        semanticLabel: 'mini_game_classic_flame'.tr,
                        color: NeonTheme.orange,
                        onTap: () => Get.to(() => const GameDemoScreen()),
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      CommonButton(
                        label: 'mini_game_sprite_arena'.tr,
                        semanticLabel: 'mini_game_sprite_arena'.tr,
                        color: NeonTheme.cyan,
                        onTap: () => Get.to(() => const SpriteArenaDemoScreen()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
