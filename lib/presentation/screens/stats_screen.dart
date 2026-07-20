import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// I35: màn hình tổng hợp số liệu trọn đời, chỉ đọc — không sửa state.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static List<(IconData, Color, String, RxInt Function(GameController))>
  get _metrics => [
    (
      Icons.diamond_rounded,
      NeonTheme.cyan,
      'stats_total_gems_popped'.tr,
      (c) => c.totalGemsPopped,
    ),
    (
      Icons.bolt_rounded,
      NeonTheme.magenta,
      'stats_max_combo'.tr,
      (c) => c.maxComboEver,
    ),
    (
      Icons.star_rounded,
      NeonTheme.gold,
      'stats_levels_three_starred'.tr,
      (c) => c.levelsThreeStarred,
    ),
    (
      Icons.check_circle_rounded,
      NeonTheme.lime,
      'stats_boards_cleared'.tr,
      (c) => c.boardsFullyCleared,
    ),
    (
      Icons.flash_on_rounded,
      NeonTheme.orange,
      'stats_boosters_used'.tr,
      (c) => c.totalBoostersUsed,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'stats_screen_title'.tr,
                color: NeonTheme.orange,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  itemCount: _metrics.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: NeonTheme.s16),
                  itemBuilder: (context, i) {
                    final (icon, color, label, selector) = _metrics[i];
                    return Container(
                      padding: const EdgeInsets.all(NeonTheme.s16),
                      decoration: BoxDecoration(
                        color: NeonTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color, width: 1.5),
                        boxShadow: NeonTheme.drop(),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 28),
                          const SizedBox(width: NeonTheme.s16),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: NeonTheme.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Obx(
                            () => Text(
                              '${selector(gameCtrl).value}',
                              style: TextStyle(
                                color: color,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
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
