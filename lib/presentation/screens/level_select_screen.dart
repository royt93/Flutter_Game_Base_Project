import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import 'game_screen.dart';

/// Danh sách phẳng 200 level (không world map) — khoá theo [unlockedLevel].
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

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
                  return GridView.builder(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: NeonTheme.s8,
                          crossAxisSpacing: NeonTheme.s8,
                          childAspectRatio: 1,
                        ),
                    itemCount: kLevelCount,
                    itemBuilder: (context, i) {
                      final id = i + 1;
                      final locked = id > unlocked;
                      final stars = StorageService.to.getInt(
                        StorageKeys.star(id),
                      );
                      return _LevelTile(
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
