import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import 'achievements_screen.dart';

/// Giải thích luật chơi Pop Star: chạm nhóm ô cùng màu liền kề để nổ.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  static List<(IconData, Color, String, String)> get _rules => [
    (
      Icons.touch_app_rounded,
      NeonTheme.cyan,
      'guide_rule_tap_title'.tr,
      'guide_rule_tap_body'.tr,
    ),
    (
      Icons.trending_up_rounded,
      NeonTheme.magenta,
      'guide_rule_bigger_title'.tr,
      'guide_rule_bigger_body'.tr,
    ),
    (
      Icons.arrow_downward_rounded,
      NeonTheme.lime,
      'guide_rule_gravity_title'.tr,
      'guide_rule_gravity_body'.tr,
    ),
    (
      Icons.emoji_events_rounded,
      NeonTheme.yellow,
      'guide_rule_clear_title'.tr,
      'guide_rule_clear_body'.tr,
    ),
    (
      Icons.block_rounded,
      NeonTheme.orange,
      'guide_rule_nomoves_title'.tr,
      'guide_rule_nomoves_body'.tr,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'guide'.tr, color: NeonTheme.lime),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  itemCount: _rules.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: NeonTheme.s16),
                  itemBuilder: (context, i) {
                    if (i == _rules.length) {
                      return GestureDetector(
                        onTap: () => Get.to(() => const AchievementsScreen()),
                        child: Container(
                          padding: const EdgeInsets.all(NeonTheme.s16),
                          decoration: BoxDecoration(
                            color: NeonTheme.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: NeonTheme.gold,
                              width: 1.5,
                            ),
                            boxShadow: NeonTheme.drop(),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                color: NeonTheme.gold,
                                size: 28,
                              ),
                              const SizedBox(width: NeonTheme.s16),
                              Expanded(
                                child: Text(
                                  'achievements_title'.tr,
                                  style: TextStyle(
                                    color: NeonTheme.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: NeonTheme.inkSoft,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final (icon, color, title, body) = _rules[i];
                    return Container(
                      padding: const EdgeInsets.all(NeonTheme.s16),
                      decoration: BoxDecoration(
                        color: NeonTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color, width: 1.5),
                        boxShadow: NeonTheme.drop(),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: color, size: 28),
                          const SizedBox(width: NeonTheme.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: NeonTheme.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: NeonTheme.s8),
                                Text(
                                  body,
                                  style: TextStyle(
                                    color: NeonTheme.inkSoft,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
