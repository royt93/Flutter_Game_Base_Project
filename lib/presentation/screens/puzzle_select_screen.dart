import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../data/puzzles.dart';
import '../controllers/game_controller.dart';
import '../controllers/puzzle_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import 'game_screen.dart';

/// W19.2 — Màn chọn Cấu đố: lưới 8 cấu đố mở khoá tuần tự, hiện sao + trạng thái.
class PuzzleSelectScreen extends StatelessWidget {
  const PuzzleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = Get.find<GameController>();
    final pc = Get.put(PuzzleController(g), permanent: true);
    const accent = NeonTheme.lime;
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'puzzle_title'.tr,
                color: accent,
                actions: [CoinChip(g)],
              ),
              Expanded(
                child: Obx(() {
                  pc.stars.length; // theo dõi reactive
                  pc.unlocked.value;
                  return ListView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    children: [
                      _banner(pc, accent),
                      if (pc.hardVariantUnlocked) ...[
                        const SizedBox(height: NeonTheme.s8),
                        _hardVariantToggle(pc, accent),
                      ],
                      const SizedBox(height: NeonTheme.s16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: kPuzzles.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: NeonTheme.s8,
                              crossAxisSpacing: NeonTheme.s8,
                              childAspectRatio: 0.85,
                            ),
                        itemBuilder: (_, i) =>
                            _tile(g, pc, kPuzzles[i], accent),
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

  Widget _banner(PuzzleController pc, Color accent) => Container(
    padding: const EdgeInsets.all(NeonTheme.s16),
    decoration: BoxDecoration(
      color: NeonTheme.panel.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent, width: 1.6),
      boxShadow: NeonTheme.glow(accent, blur: 10),
    ),
    child: Column(
      children: [
        Text(
          'puzzle_sub'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: accent, blurRadius: 8)],
          ),
        ),
        const SizedBox(height: NeonTheme.s8),
        Text(
          pc.allSolved
              ? 'puzzle_all_done'.tr
              : 'puzzle_progress'.trParams({
                  'a': '${pc.solvedCount}',
                  'b': '${kPuzzles.length}',
                }),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: pc.allSolved ? NeonTheme.yellow : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _hardVariantToggle(PuzzleController pc, Color accent) => Center(
    child: Obx(
      () => GestureDetector(
        onTap: () => pc.hardVariantOn.toggle(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NeonTheme.s16,
            vertical: NeonTheme.s8,
          ),
          decoration: BoxDecoration(
            color: NeonTheme.panel.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: pc.hardVariantOn.value ? NeonTheme.red : accent,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.whatshot_rounded,
                size: 18,
                color: pc.hardVariantOn.value ? NeonTheme.red : Colors.white38,
              ),
              const SizedBox(width: NeonTheme.s8),
              Flexible(
                child: Text(
                  (pc.hardVariantOn.value
                          ? 'puzzle_hard_on'
                          : 'puzzle_hard_off')
                      .tr,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _tile(
    GameController g,
    PuzzleController pc,
    PuzzleDef def,
    Color accent,
  ) {
    final unlocked = pc.isUnlocked(def.id);
    final star = pc.starsOf(def.id);
    final c = unlocked ? accent : Colors.grey.shade700;
    return GestureDetector(
      onTap: unlocked
          ? () {
              final hard = def.id == kPuzzles.length && pc.hardVariantOn.value;
              g.startPuzzle(def, hard: hard);
              Get.to(() => const GameScreen());
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c, width: 1.6),
          boxShadow: unlocked ? NeonTheme.glow(c, blur: 7) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unlocked)
              Text(
                '${def.id}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: c, blurRadius: 8)],
                ),
              )
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
                    size: 10,
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
}
