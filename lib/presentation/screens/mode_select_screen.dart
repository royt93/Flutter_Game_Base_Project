import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/label_fit.dart';
import '../../data/gauntlet_modifiers.dart';
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
                        _modeTile(
                          icon: Icons.bolt_rounded,
                          color: NeonTheme.magenta,
                          label: 'mode_combo_rush_label'.tr,
                          onTap: () {
                            Get.back();
                            gameCtrl.startSideMode(GameMode.comboRush);
                            Get.to(() => const GameScreen());
                          },
                        ),
                        _modeTile(
                          icon: Icons.ac_unit_rounded,
                          color: NeonTheme.cyan,
                          label: 'mode_frost_rush_label'.tr,
                          onTap: () {
                            Get.back();
                            gameCtrl.startSideMode(GameMode.frostRush);
                            Get.to(() => const GameScreen());
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: NeonTheme.s24),
                    _modeGroup(
                      label: 'modes_group_challenge'.tr,
                      tiles: [
                        // F18: "Bàn hôm nay" — bàn tự vẽ của chính người chơi
                        // (hoặc preset) thành thử thách có thưởng.
                        _modeTile(
                          key: const Key('mode_puzzle_daily'),
                          icon: Icons.today_rounded,
                          color: NeonTheme.purple,
                          // F18: nhãn cho biết hôm nay đã chơi chưa — mode này
                          // chỉ ghi điểm 1 lần/ngày nên người chơi cần biết
                          // trước khi vào.
                          label: gameCtrl.canRecordPuzzleDailyScore
                              ? 'puzzle_daily_label'.tr
                              : '${'puzzle_daily_label'.tr}\n'
                                    '(${'puzzle_daily_done'.tr})',
                          onTap: () {
                            if (!gameCtrl.startPuzzleDaily()) return;
                            Get.back();
                            Get.to(() => const GameScreen());
                          },
                        ),
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
                              // F17: hết bản đồ là ĐÚNG chỗ để chào bán bằng
                              // Combo Token — người chơi đang muốn chơi ngay.
                              // Nút chỉ hiện khi thật sự mua được, để dialog
                              // không quảng cáo thứ bấm vào không ăn.
                              NeonDialog.show(
                                context: context,
                                title: 'treasure_map_title'.tr,
                                color: NeonTheme.teal,
                                message: 'treasure_no_maps'.tr,
                                actions: [
                                  if (gameCtrl.canBuyTreasureMap)
                                    NeonDialogAction(
                                      label: 'token_buy_map'.trParams({
                                        'n':
                                            '${GameController.tokenCostTreasureMap}',
                                      }),
                                      color: NeonTheme.cyan,
                                      onTap: gameCtrl.buyTreasureMap,
                                    ),
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
                        // F21: Mirror Draft cũng là mode 2 người trên cùng
                        // một máy — đứng cạnh Pass-and-Play.
                        _modeTile(
                          key: const Key('mode_mirror_draft'),
                          icon: Icons.flip_camera_android_rounded,
                          color: NeonTheme.magenta,
                          label: 'mirror_draft_label'.tr,
                          onTap: () {
                            Get.back();
                            gameCtrl.startMirrorDraft();
                            Get.to(() => const GameScreen());
                          },
                        ),
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
                    const SizedBox(height: NeonTheme.s24),
                    _modeGroup(
                      label: 'modes_group_remix'.tr,
                      tiles: [
                        for (final remix in kRemixLevels)
                          _modeTile(
                            icon: remix.modifier.icon,
                            color: NeonTheme.pink,
                            label:
                                '${worldForLevel(remix.levelId).nameKey.tr} '
                                '#${remix.levelId}',
                            semanticLabel: remix.modifier.nameKey.tr,
                            onTap: () {
                              Get.back();
                              gameCtrl.startRemixLevel(
                                remix.levelId,
                                remix.modifier,
                              );
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

  /// Bề ngang nhãn dưới mỗi ô mode. Giữ nguyên 60 để `Wrap` vẫn xếp 4 cột
  /// trên máy hẹp 360dp; chữ co lại thay vì ô nới ra.
  static const double _kTileLabelWidth = 60;

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
    Key? key,
  }) {
    return Column(
      key: key,
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
          width: _kTileLabelWidth,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              // Thu nhỏ khi một từ đơn dài hơn ô. Tiếng Đức vỡ ở đây:
              // "Doppelspiegel" và "Zitronenwüste" bị ngắt giữa từ.
              fontSize: fitFontSizeForLongestWord(label, _kTileLabelWidth),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
