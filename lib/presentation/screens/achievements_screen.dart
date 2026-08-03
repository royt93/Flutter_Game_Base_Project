import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/achievements.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// I22: danh sách 25 thành tựu vanity-only, mỗi mốc mở khoá đúng 1 lần.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'achievements_title'.tr, color: NeonTheme.gold),
              Expanded(
                child: Obx(() {
                  // ListView.itemBuilder chạy lazy trong layout, ngoài phạm vi
                  // đồng bộ mà Obx theo dõi read — phải đọc trực tiếp các Rx
                  // ở đây để Obx đăng ký được observable (nếu không GetX throw
                  // "improper use of Obx" vì tưởng builder không đọc gì).
                  gameCtrl.unlockedAchievementIds.length;
                  gameCtrl.activeAchievementTitleId.value;
                  for (final m in AchievementMetric.values) {
                    gameCtrl.metricValue(m);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    itemCount: kAchievements.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: NeonTheme.s8),
                    itemBuilder: (context, i) {
                      final a = kAchievements[i];
                      final unlocked = gameCtrl.unlockedAchievementIds.contains(
                        a.id,
                      );
                      final progress = gameCtrl.metricValue(a.metric);
                      final isActiveTitle =
                          gameCtrl.activeAchievementTitleId.value == a.id;
                      return _AchievementRow(
                        achievement: a,
                        unlocked: unlocked,
                        progress: progress,
                        isActiveTitle: isActiveTitle,
                        onToggleTitle: !unlocked
                            ? null
                            : () => isActiveTitle
                                  ? gameCtrl.clearActiveTitle()
                                  : gameCtrl.setActiveTitle(a.id),
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

class _AchievementRow extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  final int progress;
  final bool isActiveTitle;
  final VoidCallback? onToggleTitle;

  const _AchievementRow({
    required this.achievement,
    required this.unlocked,
    required this.progress,
    required this.isActiveTitle,
    required this.onToggleTitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? NeonTheme.gold : NeonTheme.inkSoft;
    final ratio = unlocked
        ? 1.0
        : (progress / achievement.threshold).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: unlocked ? 2.5 : 1.5),
        boxShadow: unlocked ? NeonTheme.glow(color) : null,
      ),
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.6,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              unlocked ? Icons.emoji_events_rounded : Icons.lock_rounded,
              color: color,
              size: 28,
            ),
            const SizedBox(width: NeonTheme.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.titleKey.tr,
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.descKey.trParams({
                      'n': '${achievement.threshold}',
                    }),
                    style: TextStyle(
                      color: NeonTheme.inkSoft,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: NeonTheme.s8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: NeonTheme.cardAlt,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unlocked
                        ? 'achievements_done'.tr
                        : '${progress.clamp(0, achievement.threshold)}/${achievement.threshold}',
                    style: TextStyle(
                      color: NeonTheme.inkSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onToggleTitle != null) ...[
                    const SizedBox(height: NeonTheme.s8),
                    GestureDetector(
                      onTap: onToggleTitle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: NeonTheme.s8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActiveTitle
                              ? NeonTheme.gold
                              : NeonTheme.cardAlt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isActiveTitle
                              ? 'achievement_title_clear_button'.tr
                              : 'achievement_title_set_button'.tr,
                          style: TextStyle(
                            color: isActiveTitle
                                ? NeonTheme.ink
                                : NeonTheme.inkSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: NeonTheme.s8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: NeonTheme.gold,
                  size: 16,
                ),
                Text(
                  '+${achievement.coinReward}',
                  style: const TextStyle(
                    color: NeonTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
