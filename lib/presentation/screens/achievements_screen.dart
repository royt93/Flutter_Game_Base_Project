import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../data/achievements.dart';
import '../controllers/achievement_controller.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// Màn thành tựu — lưới thẻ, thanh tiến trình, nút NHẬN khi đạt.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = Get.find<GameController>();
    final ac = Get.put(AchievementController(g));
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'achievements'.tr,
                color: NeonTheme.yellow,
                actions: [_coinChip(g)],
              ),
              Expanded(
                child: Obx(() {
                  // chạm các Rx để Obx rebuild khi tiến trình/đã-nhận đổi
                  ac.claimed.length;
                  g.totalWins.value;
                  g.bestCombo.value;
                  g.bestWinStreak.value;
                  g.unlockedLevel.value;
                  g.coinsEarnedTotal.value;
                  g.stars.length;
                  return GridView.builder(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: NeonTheme.s16,
                      crossAxisSpacing: NeonTheme.s16,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: kAchievements.length,
                    itemBuilder: (_, i) => _card(ac, kAchievements[i]),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(AchievementController ac, Achievement a) {
    final unlocked = ac.isUnlocked(a);
    final claimed = ac.isClaimed(a);
    final canClaim = ac.canClaim(a);
    final c = unlocked ? a.color : Colors.grey.shade700;
    final cur = ac.currentValue(a.stat).clamp(0, a.threshold);
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c, width: unlocked ? 2.2 : 1.4),
        boxShadow: unlocked ? NeonTheme.glow(c, blur: 10) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(unlocked ? a.icon : Icons.lock_rounded,
                  color: c, size: 44, shadows: [Shadow(color: c, blurRadius: 12)]),
              if (claimed)
                Positioned(
                  right: -10,
                  top: -6,
                  child: Icon(Icons.check_circle_rounded,
                      color: NeonTheme.lime, size: 20),
                ),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          Text(
            a.titleKey.tr,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: c, blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            a.descKey.trParams({'n': '${a.threshold}'}),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          // tiến trình
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ac.progress(a),
              minHeight: 6,
              backgroundColor: NeonTheme.panel,
              valueColor: AlwaysStoppedAnimation(c),
            ),
          ),
          const SizedBox(height: 3),
          Text('$cur / ${a.threshold}',
              style: const TextStyle(
                fontFamily: 'Orbitron',
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: NeonTheme.s8),
          _footer(ac, a, canClaim, claimed),
        ],
      ),
    );
  }

  Widget _footer(
      AchievementController ac, Achievement a, bool canClaim, bool claimed) {
    if (claimed) {
      return Text('ach_claimed'.tr,
          style: const TextStyle(
            fontFamily: 'Orbitron',
            color: NeonTheme.lime,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ));
    }
    if (canClaim) {
      return GestureDetector(
        onTap: () {
          final got = ac.claim(a);
          final ctx = Get.context;
          if (got > 0 && ctx != null) {
            ScaffoldMessenger.of(ctx)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text('+$got 💰',
                    style: const TextStyle(fontFamily: 'Orbitron')),
                backgroundColor: NeonTheme.panel,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(milliseconds: 900),
              ));
          }
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: NeonTheme.lime,
            borderRadius: BorderRadius.circular(12),
            boxShadow: NeonTheme.glow(NeonTheme.lime, blur: 10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${'ach_claim'.tr} +${a.reward}',
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                )),
          ]),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.monetization_on_rounded,
          color: NeonTheme.yellow, size: 13),
      const SizedBox(width: 3),
      Text('+${a.reward}',
          style: const TextStyle(
            fontFamily: 'Orbitron',
            color: NeonTheme.yellow,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          )),
    ]);
  }

  Widget _coinChip(GameController g) {
    return Container(
      margin: const EdgeInsets.only(right: NeonTheme.s8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NeonTheme.yellow, width: 1.5),
        boxShadow: NeonTheme.glow(NeonTheme.yellow, blur: 6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.monetization_on_rounded,
            color: NeonTheme.yellow, size: 18),
        const SizedBox(width: 5),
        Obx(() => Text('${g.coins.value}',
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ))),
      ]),
    );
  }
}
