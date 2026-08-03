import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/worlds.dart';
import '../controllers/game_controller.dart';
import '../controllers/pass_and_play_controller.dart';
import '../controllers/treasure_map_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/neon_icon.dart';
import 'boss_rush_screen.dart';
import 'game_screen.dart';

/// I70: màn hình riêng thay cho dialog "Chọn chế độ" cũ (từng bị chê xấu/chật
/// dù đã có scroll nội bộ) — full-screen route giống BossRushScreen/
/// LevelSelectScreen, không giới hạn chiều cao nội dung.
class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'modes_title'.tr, color: NeonTheme.indigo),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  children: [
                    _modeGroup(
                      label: 'modes_group_core'.tr,
                      tiles: [
                        _modeTile(
                          icon: Icons.timer_rounded,
                          color: NeonTheme.orange,
                          label: 'mode_time_attack_label'.tr,
                          onTap: () {
                            Get.back();
                            gameCtrl.startSideMode(GameMode.timeAttack);
                            Get.to(() => const GameScreen());
                          },
                        ),
                        _modeTile(
                          icon: Icons.spa_rounded,
                          color: NeonTheme.teal,
                          label: 'mode_zen_label'.tr,
                          onTap: () {
                            Get.back();
                            gameCtrl.startSideMode(GameMode.zen);
                            Get.to(() => const GameScreen());
                          },
                        ),
                        _modeTile(
                          icon: Icons.all_inclusive_rounded,
                          color: NeonTheme.indigo,
                          label: 'mode_endless_label'.tr,
                          onTap: () {
                            Get.back();
                            gameCtrl.startEndless();
                            Get.to(() => const GameScreen());
                          },
                        ),
                        _modeTile(
                          icon: Icons.flip_rounded,
                          color: NeonTheme.cyan,
                          label: 'mode_mirror_label'.tr,
                          onTap: () {
                            Get.back();
                            gameCtrl.startMirrorMode();
                            Get.to(() => const GameScreen());
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: NeonTheme.s24),
                    _modeGroup(
                      label: 'modes_group_challenge'.tr,
                      tiles: [
                        _modeTile(
                          icon: Icons.local_fire_department_rounded,
                          color: NeonTheme.red,
                          label: 'mode_boss_rush_label'.tr,
                          onTap: () {
                            Get.back();
                            Get.to(() => const BossRushScreen());
                          },
                        ),
                        _modeTile(
                          icon: gameCtrl.todaysGauntletModifier.icon,
                          color: NeonTheme.gold,
                          label: gameCtrl.todaysGauntletModifier.nameKey.tr,
                          semanticLabel: 'mode_gauntlet_label'.tr,
                          onTap: () {
                            Get.back();
                            gameCtrl.startGauntlet();
                            Get.to(() => const GameScreen());
                          },
                        ),
                        _modeTile(
                          icon: Icons.map_rounded,
                          color: NeonTheme.teal,
                          label: 'treasure_map_title'.tr,
                          onTap: () {
                            if (gameCtrl.treasureMapCount.value <= 0) {
                              NeonDialog.show(
                                context: context,
                                title: 'treasure_map_title'.tr,
                                color: NeonTheme.teal,
                                message: 'treasure_no_maps'.tr,
                                actions: [
                                  NeonDialogAction(
                                    label: 'coll_close'.tr,
                                    color: NeonTheme.teal,
                                    onTap: () {},
                                  ),
                                ],
                              );
                              return;
                            }
                            final expedition = Get.put(
                              TreasureMapController(gameCtrl),
                            );
                            if (expedition.startExpedition()) {
                              Get.back();
                              Get.to(() => const GameScreen());
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: NeonTheme.s24),
                    _modeGroup(
                      label: 'modes_group_social'.tr,
                      tiles: [
                        _modeTile(
                          icon: Icons.people_rounded,
                          color: NeonTheme.purple,
                          label: 'duel_title'.tr,
                          onTap: () {
                            Get.back();
                            final duel = Get.put(
                              PassAndPlayController(gameCtrl),
                            );
                            duel.startDuel();
                            Get.to(() => const GameScreen());
                          },
                        ),
                        _modeTile(
                          icon: Icons.event_rounded,
                          color: NeonTheme.magenta,
                          label: worldForLevel(
                            gameCtrl.featuredLevelId,
                          ).nameKey.tr,
                          semanticLabel: 'mode_weekly_featured_label'.tr,
                          onTap: () {
                            Get.back();
                            gameCtrl.startWeeklyFeatured();
                            Get.to(() => const GameScreen());
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeGroup({required String label, required List<Widget> tiles}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.start,
          spacing: NeonTheme.s16,
          runSpacing: NeonTheme.s16,
          children: tiles,
        ),
      ],
    );
  }

  Widget _modeTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeonIconButton(
          icon,
          color: color,
          size: 28,
          boxed: true,
          semanticLabel: semanticLabel ?? label,
          onTap: onTap,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
