import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../core/audio_manager.dart';
import '../../core/debug_log.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/cosmetics.dart';
import '../../data/levels.dart';
import '../../data/side_mode_records.dart';
import '../../game/neon_jewel_game.dart' show BoosterMode;
import '../controllers/game_controller.dart';
import '../controllers/game_screen_controller.dart';
import '../controllers/side_mode_record_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/neon_icon.dart';
import '../widgets/story_overlay.dart';

/// Màn chơi — StatelessWidget thuần GetX (không setState).
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<GameController>();
    final sc = Get.put(GameScreenController(ctrl));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) sc.confirmQuit();
      },
      child: Scaffold(
        body: Obx(() {
          // W25.2 — Theme đổi màu theo MODE (side-mode có màu riêng); campaign theo thế giới.
          final accent = ctrl.modeAccent;
          return NeonBg(
            accent: accent,
            child: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      _buildHud(ctrl, sc),
                      Expanded(
                        child: Obx(() {
                          final v = sc.gameVersion.value;
                          return Stack(
                            children: [
                              GameWidget(key: ValueKey(v), game: sc.game),
                              // A fix: Ghost overlay — pulsing highlight trên 2 gem ghost sẽ swap
                              if (ctrl.isGhostMode.value)
                                _GhostHintOverlay(ctrl: ctrl, sc: sc),
                            ],
                          );
                        }),
                      ),
                      _buildBoosterBar(ctrl, sc),
                      const SizedBox(height: NeonTheme.s8),
                    ],
                  ),
                ),
                // Overlay dialog render TRÊN GameWidget (Flame không đè được)
                Obx(() => _overlay(ctrl, sc)),
                // Overlay hướng dẫn lần đầu (trên cùng)
                Obx(() {
                  sc.tutorialStep.value; // observe để rebuild khi đổi bước
                  return sc.tutorialOpen.value
                      ? _tutorialOverlay(sc)
                      : const SizedBox.shrink();
                }),
                // Overlay cốt truyện outro (sau khi thắng màn cuối thế giới)
                const StoryOverlay(),
                // W25.2 — Mở-màn per-mode (tên mode + màu accent, ~1.3s, không chặn input)
                Obx(
                  () => sc.showModeIntro.value
                      ? _ModeIntroOverlay(
                          label: sc.modeIntroLabelKey.tr,
                          accent: ctrl.modeAccent,
                          reduced: ActiveCosmetics.reducedMotion,
                          onDone: () {
                            if (!sc.isClosed) sc.showModeIntro.value = false;
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _overlay(GameController ctrl, GameScreenController sc) {
    switch (sc.ui.value) {
      case GameUi.playing:
        return const SizedBox.shrink();
      case GameUi.quit:
        return NeonDialog.overlay(
          onBarrier: sc.closeOverlay,
          panel: NeonDialog.panel(
            title: 'quit_title'.tr,
            color: NeonTheme.magenta,
            icon: Icons.exit_to_app_rounded,
            message: 'quit_msg'.tr,
            actions: [
              NeonDialogAction(
                label: 'cancel'.tr,
                color: NeonTheme.cyan,
                onTap: sc.closeOverlay,
              ),
              NeonDialogAction(
                label: 'confirm'.tr,
                color: NeonTheme.magenta,
                onTap: sc.quit,
              ),
            ],
          ),
        );
      case GameUi.win:
        return NeonDialog.overlay(panel: _resultPanel(ctrl, sc, true));
      case GameUi.lose:
        return NeonDialog.overlay(panel: _resultPanel(ctrl, sc, false));
    }
  }

  // -------------------------------------------------------------- Tutorial
  Widget _tutorialOverlay(GameScreenController sc) {
    final step = sc.tutorialStep.value;
    final last = step >= GameScreenController.tutorialSteps - 1;
    const icons = [
      Icons.swipe_rounded,
      Icons.bolt_rounded,
      Icons.auto_awesome_rounded,
    ];
    return NeonDialog.overlay(
      onBarrier: sc.tutorialNext,
      // vuốt trái → bước tiếp, vuốt phải → lùi bước
      panel: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -100) {
            sc.tutorialNext();
          } else if (v > 100) {
            sc.tutorialPrev();
          }
        },
        child: NeonDialog.panel(
          title: 'tut_title'.tr,
          color: NeonTheme.cyan,
          icon: icons[step],
          message: 'tut_${step + 1}'.tr,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(GameScreenController.tutorialSteps, (
                  i,
                ) {
                  final on = i == step;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: on ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: on ? NeonTheme.cyan : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: on
                          ? NeonTheme.glow(NeonTheme.cyan, blur: 6)
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: NeonTheme.s8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.swipe_left_rounded,
                    color: Colors.white38,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'tut_swipe_hint'.tr,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (!last)
              NeonDialogAction(
                label: 'tut_skip'.tr,
                color: NeonTheme.magenta,
                onTap: sc.tutorialSkip,
              ),
            NeonDialogAction(
              label: last ? 'tut_start'.tr : 'tut_next'.tr,
              color: NeonTheme.lime,
              onTap: sc.tutorialNext,
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultPanel(GameController ctrl, GameScreenController sc, bool win) {
    // Zen Mode: result khi người chơi thoát — hiện điểm + kỷ lục + xu nhận.
    if (ctrl.isZen.value) {
      final isNewBest = ctrl.score.value >= ctrl.zenHigh.value;
      return NeonDialog.panel(
        title: 'zen_title'.tr,
        color: NeonTheme.cyan,
        icon: Icons.spa_rounded,
        message:
            '${'hud_score'.tr}: ${fmtNum(ctrl.score.value)}'
            '${isNewBest ? '  🏆' : ''}\n'
            '${'zen_best'.tr}: ${fmtNum(ctrl.zenHigh.value)}'
            '${ctrl.lastCoinReward > 0 ? '  ·  +${fmtNum(ctrl.lastCoinReward)} 💰' : ''}',
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: sc.quit,
          ),
        ],
      );
    }
    // Endless: chỉ có màn kết thúc (hết lượt) — hiện điểm + kỷ lục, không sao.
    if (ctrl.isEndless.value) {
      return NeonDialog.panel(
        title: 'endless_over'.tr,
        color: NeonTheme.purple,
        icon: Icons.all_inclusive_rounded,
        message:
            '${'hud_score'.tr}: ${fmtNum(ctrl.score.value)}\n'
            '${'endless_best'.tr}: ${fmtNum(ctrl.endlessHigh.value)}  ·  '
            '${'stage_n'.trParams({'n': '${ctrl.endlessStage.value}'})}',
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: sc.quit,
          ),
        ],
      );
    }
    // Boss: chế độ phụ — không tốn mạng, luôn cho đánh lại.
    if (ctrl.isBoss.value) {
      return NeonDialog.panel(
        title: win ? 'victory'.tr : 'retry'.tr,
        color: win ? NeonTheme.lime : NeonTheme.orange,
        icon: win ? Icons.emoji_events_rounded : Icons.coronavirus_rounded,
        message:
            '${'boss_stage'.tr} ${ctrl.bossStage.value}  ·  ${'boss_hp'.tr}: '
            '${fmtNum(ctrl.bossHp.value)}/${fmtNum(ctrl.bossMaxHp.value)}',
        content: win ? _celebration(ctrl) : null,
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.orange,
            onTap: sc.quit,
          ),
        ],
      );
    }
    // Rhythm: chế độ phụ — không tốn mạng, luôn cho chơi lại.
    if (ctrl.isRhythm.value) {
      return NeonDialog.panel(
        title: win ? 'victory'.tr : 'retry'.tr,
        color: win ? NeonTheme.lime : NeonTheme.cyan,
        icon: win ? Icons.emoji_events_rounded : Icons.music_note_rounded,
        message:
            '${'hud_score'.tr}: ${fmtNum(ctrl.score.value)} / ${fmtNum(ctrl.targetScore.value)}'
            '  ·  ${'rhythm_groove'.tr} ${ctrl.groove.value}',
        content: win ? _celebration(ctrl) : null,
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: sc.quit,
          ),
        ],
      );
    }
    // Trọng lực động: chế độ phụ — không tốn mạng, luôn cho chơi lại.
    if (ctrl.isGravity.value) {
      return NeonDialog.panel(
        title: win ? 'victory'.tr : 'retry'.tr,
        color: win ? NeonTheme.lime : NeonTheme.cyan,
        icon: win ? Icons.emoji_events_rounded : Icons.swap_vert_rounded,
        message:
            '${'hud_score'.tr}: ${fmtNum(ctrl.score.value)} / ${fmtNum(ctrl.targetScore.value)}',
        content: win ? _celebration(ctrl) : null,
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: sc.quit,
          ),
        ],
      );
    }
    // Color Rush: chế độ phụ — không tốn mạng, luôn cho chơi lại.
    if (ctrl.isColorRush.value) {
      return NeonDialog.panel(
        title: win ? 'victory'.tr : 'retry'.tr,
        color: win ? NeonTheme.lime : NeonTheme.orange,
        icon: win
            ? Icons.emoji_events_rounded
            : Icons.local_fire_department_rounded,
        message:
            '${'hud_score'.tr}: ${fmtNum(ctrl.score.value)} / ${fmtNum(ctrl.targetScore.value)}',
        content: win ? _celebration(ctrl) : null,
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: sc.quit,
          ),
        ],
      );
    }
    // Soda (Wave 14): chế độ phụ — không tốn mạng, luôn cho chơi lại.
    if (ctrl.isSoda.value) {
      return NeonDialog.panel(
        title: win ? 'victory'.tr : 'retry'.tr,
        color: win ? NeonTheme.lime : NeonTheme.cyan,
        icon: win ? Icons.emoji_events_rounded : Icons.local_drink_rounded,
        message:
            '${'soda_hud'.tr}: ${ctrl.sodaCollected.value} / ${ctrl.level.sodaTarget}',
        content: win ? _celebration(ctrl) : null,
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: sc.quit,
          ),
        ],
      );
    }
    // Sinh tồn (Survival — Wave 15): chỉ có màn kết thúc (hết giờ) — điểm + kỷ lục.
    if (ctrl.isSurvival.value) {
      return NeonDialog.panel(
        title: 'survival_over'.tr,
        color: NeonTheme.orange,
        icon: Icons.timer_rounded,
        message:
            '${'hud_score'.tr}: ${fmtNum(ctrl.score.value)}\n'
            '${'survival_best'.tr}: ${fmtNum(ctrl.survivalHigh.value)}',
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.orange,
            onTap: sc.quit,
          ),
        ],
      );
    }
    // Rush: chế độ phụ tính điểm cao, kết thúc khi hết giờ.
    if (ctrl.isRush.value) {
      final best = SideModeRecordController.maybe?.recordOf(SideModeKind.rush);
      return NeonDialog.panel(
        title: 'rush_title'.tr,
        color: NeonTheme.yellow,
        icon: Icons.bolt_rounded,
        message:
            '${'hud_score'.tr}: ${fmtNum(ctrl.score.value)}'
            '${best == null ? '' : '\n${'rush_best'.tr}: ${fmtNum(best)}'}'
            '${ctrl.lastCoinReward > 0 ? '\n+${fmtNum(ctrl.lastCoinReward)} ${'coins_short'.tr}' : ''}',
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: sc.quit,
          ),
        ],
      );
    }
    // Mê cung neon (Labyrinth — Wave 15): chế độ phụ — không tốn mạng, chơi lại.
    if (ctrl.isLabyrinth.value) {
      return NeonDialog.panel(
        title: win ? 'victory'.tr : 'retry'.tr,
        color: win ? NeonTheme.lime : NeonTheme.cyan,
        icon: win ? Icons.emoji_events_rounded : Icons.account_tree_rounded,
        message:
            '${'labyrinth_hud'.tr}: ${ctrl.dropped.value} / ${ctrl.level.dropTarget}',
        content: win ? _celebration(ctrl) : null,
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: sc.quit,
          ),
        ],
      );
    }
    // Thử thách hằng ngày: chế độ phụ — không tốn mạng, luôn cho chơi lại (CÙNG
    // bàn theo ngày). Thắng lần đầu/ngày → khoe streak + thưởng; chơi lại đã
    // hoàn thành → báo done. Thua → hiện mục tiêu.
    if (ctrl.isDaily.value) {
      final msg = win
          ? (ctrl.lastCoinReward > 0
                ? '${'daily_ch_streak'.tr}: ${ctrl.dailyChStreak.value}\n'
                      '${'daily_ch_reward'.trParams({'c': fmtNum(ctrl.lastCoinReward)})}'
                : 'daily_ch_done'.tr)
          : '${'hud_goal'.tr}: ${_objectiveText(ctrl)}';
      return NeonDialog.panel(
        title: win ? 'victory'.tr : 'retry'.tr,
        color: win ? NeonTheme.lime : NeonTheme.cyan,
        icon: win ? Icons.emoji_events_rounded : Icons.event_rounded,
        message: msg,
        content: win ? _celebration(ctrl) : null,
        actions: [
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: sc.quit,
          ),
        ],
      );
    }
    final cur = ctrl.currentLevel.value;
    // thua mà hết mạng → ẩn nút CHƠI LẠI (không lách cổng mạng), báo hết mạng.
    final noLives = !win && !ctrl.hasLife;
    return NeonDialog.panel(
      title: win ? 'victory'.tr : 'retry'.tr,
      color: win ? NeonTheme.lime : NeonTheme.magenta,
      icon: win ? Icons.emoji_events_rounded : Icons.refresh_rounded,
      message: noLives
          ? 'lives_none_title'.tr
          : '${'hud_goal'.tr}: ${_objectiveText(ctrl)}',
      content: win ? _celebration(ctrl) : null,
      actions: [
        if (!noLives)
          NeonDialogAction(
            label: 'btn_again'.tr,
            color: NeonTheme.cyan,
            onTap: sc.again,
          ),
        if (win && cur < kLevels.length)
          NeonDialogAction(
            label: 'btn_next'.tr,
            color: NeonTheme.lime,
            onTap: sc.proceedNextOrHome,
          )
        else
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: win ? sc.proceedNextOrHome : sc.quit,
          ),
      ],
    );
  }

  String _objectiveText(GameController ctrl) {
    // Survival (Wave 15): target giả khổng lồ (1<<28) → chỉ hiện ĐIỂM (như Endless),
    // tránh "0 / 268.435.456" xấu xí.
    if (ctrl.isSurvival.value || ctrl.isRush.value) {
      return fmtNum(ctrl.score.value);
    }
    switch (ctrl.level.objective) {
      case ObjectiveType.score:
        return '${fmtNum(ctrl.score.value)} / ${fmtNum(ctrl.targetScore.value)}';
      case ObjectiveType.collect:
        return '${ctrl.collected.value} / ${ctrl.level.collectTarget}';
      case ObjectiveType.clearJelly:
        return '${ctrl.jellyCleared.value} / ${ctrl.jellyTotal.value}';
      case ObjectiveType.timeAttack:
        return '${fmtNum(ctrl.score.value)} / ${fmtNum(ctrl.targetScore.value)}';
      case ObjectiveType.dropDown:
        return '${ctrl.dropped.value} / ${ctrl.level.dropTarget}';
      case ObjectiveType.clearObstacle:
        // jam lan thêm có thể đẩy cleared vượt total → clamp text (không hiện "17/16").
        return '${ctrl.obstacleCleared.value.clamp(0, ctrl.obstacleTotal.value)}'
            ' / ${ctrl.obstacleTotal.value}';
      case ObjectiveType.order:
        final orders = ctrl.level.orders;
        var done = 0;
        for (
          var i = 0;
          i < orders.length && i < ctrl.orderProgress.length;
          i++
        ) {
          if (ctrl.orderProgress[i] >= orders[i].target) done++;
        }
        return '$done / ${orders.length}';
      case ObjectiveType.endless:
        return fmtNum(ctrl.score.value);
      case ObjectiveType.boss:
        return '${fmtNum(ctrl.bossHp.value)} / ${fmtNum(ctrl.bossMaxHp.value)}';
      case ObjectiveType.soda:
        return '${ctrl.sodaCollected.value} / ${ctrl.level.sodaTarget}';
    }
  }

  Widget _celebration(GameController ctrl) {
    final earned = ctrl.lastStars;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final on = i < earned;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child:
                  Icon(
                    Icons.star_rounded,
                    size: 42,
                    color: on ? Colors.amber : Colors.white24,
                    shadows: on
                        ? const [Shadow(color: Colors.amber, blurRadius: 18)]
                        : null,
                  ).animate().scale(
                    delay: (i * 160).ms,
                    duration: 420.ms,
                    curve: Curves.elasticOut,
                  ),
            );
          }),
        ),
        const SizedBox(height: NeonTheme.s8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 20),
            const SizedBox(width: 6),
            Text(
              '+${fmtNum(ctrl.lastCoinReward)}',
              style: const TextStyle(
                color: NeonTheme.yellow,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (ctrl.lastStreakBonus > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: NeonTheme.orange.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NeonTheme.orange, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: NeonTheme.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${'streak_bonus'.trParams({'n': '${ctrl.winStreak.value}'})}  +${ctrl.lastStreakBonus}',
                  style: const TextStyle(
                    color: NeonTheme.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------- HUD
  Widget _buildHud(GameController ctrl, GameScreenController sc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NeonTheme.s24,
        NeonTheme.s16,
        NeonTheme.s24,
        NeonTheme.s8,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                NeonIconButton(
                  Icons.close_rounded,
                  color: NeonTheme.magenta,
                  size: 28,
                  onTap: sc.confirmQuit,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Obx(
                        () => _stageBadge(
                          ctrl.isDaily.value
                              ? 'daily_ch_title'.tr
                              : ctrl.isBoss.value
                              ? '${ctrl.bossTypeNameKey.tr} · ${'boss_title'.tr} ${ctrl.bossStage.value}'
                              : ctrl.isRhythm.value
                              ? 'rhythm_title'.tr
                              : ctrl.isGravity.value
                              ? '${'gravity_title'.tr} ${ctrl.gravityDir.value == 0 ? '↓' : '↑'}'
                              : ctrl.isColorRush.value
                              ? 'color_rush_title'.tr
                              : ctrl.isSoda.value
                              ? 'soda_title'.tr
                              : ctrl.isSurvival.value
                              ? 'survival_title'.tr
                              : ctrl.isLabyrinth.value
                              ? 'labyrinth_title'.tr
                              : ctrl.isRush.value
                              ? 'rush_title'.tr
                              : ctrl.isGhostMode.value
                              ? 'ghost_hud'.tr
                              : ctrl.isZen.value
                              ? 'zen_title'.tr
                              : ctrl.isEndless.value
                              ? 'endless_title'.tr
                              : 'stage_n'.trParams({
                                  'n': '${ctrl.currentLevel.value}',
                                }),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (AudioManager.maybe != null)
                  Obx(
                    () => NeonIconButton(
                      AudioManager.maybe!.muted.value
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: NeonTheme.cyan,
                      size: 28,
                      onTap: AudioManager.maybe!.toggleMute,
                    ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
          Obx(
            () => ctrl.isBoss.value
                ? _bossWeakHint(ctrl)
                : ctrl.isRhythm.value
                ? _rhythmHud(ctrl)
                : ctrl.isColorRush.value
                ? _colorRushHud(ctrl)
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: NeonTheme.s8),
          _infoPanel(ctrl),
          const SizedBox(height: NeonTheme.s8),
          Obx(() => _animatedBar(ctrl.objectiveProgress)),
          // Bom đếm ngược (Wave 10): chỉ báo cảnh báo khi còn bom trên bàn.
          Obx(
            () => ctrl.bombsLeft.value > 0
                ? Padding(
                    padding: const EdgeInsets.only(top: NeonTheme.s8),
                    child: _bombStrip(
                      ctrl.bombsLeft.value,
                      ctrl.bombMinTimer.value,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Cơ chế Wave 11 (băng chuyền / cổng / dispenser): badge nhắc người chơi.
          _mechanicStrip(ctrl),
        ],
      ),
    );
  }

  /// Dải cảnh báo bom: 💣 ×N + đếm ngược nhỏ nhất. Đỏ rực khi ≤3 lượt.
  Widget _bombStrip(int count, int minTimer) {
    final danger = minTimer <= 3;
    final color = danger ? NeonTheme.magenta : NeonTheme.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: NeonTheme.glow(color, blur: danger ? 10 : 5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeonIcon(Icons.dangerous_rounded, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            '${'bomb_left'.tr}: $count  •  ${'bomb_timer'.tr}: $minTimer',
            style: TextStyle(
              color: danger ? color : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Color Rush HUD: chip "MÀU NÓNG ●" (chấm theo màu đang nóng) + nhắc bội điểm.
  Widget _colorRushHud(GameController ctrl) {
    final hot =
        NeonTheme.gemColors[ctrl.colorRushHot.value.clamp(
          0,
          NeonTheme.gemColors.length - 1,
        )];
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: NeonTheme.s8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hot.withValues(alpha: 0.7), width: 1.5),
          boxShadow: NeonTheme.glow(hot, blur: 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'color_rush_hot'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hot,
                boxShadow: NeonTheme.glow(hot, blur: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dải badge cơ chế Wave 11 (băng chuyền / cổng / dispenser) — hiện theo màn.
  Widget _mechanicStrip(GameController ctrl) {
    final idx = ctrl.level.index;
    final widgets = <Widget>[];
    if (kConveyorSpec.containsKey(idx)) {
      widgets.add(
        _mechBadge(
          Icons.swap_horiz_rounded,
          'conveyor_title'.tr,
          NeonTheme.cyan,
        ),
      );
    }
    if (kPortalSpec.containsKey(idx)) {
      widgets.add(
        _mechBadge(
          Icons.blur_circular_rounded,
          'portal_title'.tr,
          NeonTheme.lime,
        ),
      );
    }
    if (kDispenserSpec.containsKey(idx)) {
      widgets.add(
        Obx(
          () => _mechBadge(
            Icons.auto_awesome_rounded,
            '${'dispenser_title'.tr} ${ctrl.dispenserCountdown.value}',
            NeonTheme.yellow,
          ),
        ),
      );
    }
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: NeonTheme.s8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: widgets,
      ),
    );
  }

  Widget _mechBadge(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: NeonTheme.panel.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.6), width: 1.4),
      boxShadow: NeonTheme.glow(color, blur: 5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeonIcon(icon, color: color, size: 16),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  /// Chỉ báo "ĐIỂM YẾU" của boss: chấm màu cần đánh trúng để ×2 sát thương.
  Widget _bossWeakHint(GameController ctrl) {
    final weakC = NeonTheme.gemColors[ctrl.bossWeakColor.value];
    final phase = ctrl.bossPhase;
    final ratio = ctrl.bossMaxHp.value == 0
        ? 0.0
        : (ctrl.bossHp.value / ctrl.bossMaxHp.value).clamp(0.0, 1.0);
    // Màu HP bar: cyan (P0) → yellow (P1) → red (P2)
    final barColor = phase == 2
        ? NeonTheme.magenta
        : phase == 1
        ? NeonTheme.yellow
        : NeonTheme.cyan;
    final phaseLabel = phase == 2
        ? 'PHASE 3'
        : phase == 1
        ? 'PHASE 2'
        : 'PHASE 1';

    return Padding(
      padding: const EdgeInsets.only(top: NeonTheme.s8),
      child: Column(
        children: [
          // HP bar với màu theo phase
          Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [BoxShadow(color: barColor, blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              )
              .animate(key: ValueKey('boss_hp_phase_$phase'))
              .shimmer(
                duration: 600.ms,
                color: barColor.withValues(alpha: 0.6),
              ),
          const SizedBox(height: 6),
          // Hàng 2: phase badge + weak color hint. Wrap để chịu được font scale lớn.
          Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Phase badge
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: barColor, width: 1),
                        ),
                        child: Text(
                          phaseLabel,
                          style: TextStyle(
                            fontFamily: 'Baloo2',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: barColor,
                          ),
                        ),
                      )
                      .animate(key: ValueKey('boss_phase_badge_$phase'))
                      .fadeIn(duration: 300.ms)
                      .scale(begin: const Offset(0.8, 0.8)),
                  Text(
                    'boss_weak'.tr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: weakC,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: weakC, blurRadius: 10)],
                    ),
                  ),
                  Text(
                    '×2',
                    style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: weakC,
                    ),
                  ),
                ],
              )
              .animate(key: ValueKey('boss_weak_${ctrl.bossWeakColor.value}'))
              .fadeIn(duration: 300.ms),
          // Flash boss-attack + phase-up: GỘP vào 1 vùng CHIỀU CAO CỐ ĐỊNH 24px.
          // Root cause "board giật về bottom" (probe xác nhận: GameWidget co 19px):
          // trước đây 2 dòng flash xuất hiện/biến mất làm Column HUD đổi height →
          // Expanded(GameWidget) co lại → board re-center → cả bàn dịch. Đặt height
          // cố định + Stack overlay → HUD KHÔNG bao giờ đổi height → board đứng yên.
          const SizedBox(height: 4),
          SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Flash khi boss attack
                Obx(
                  () => ctrl.bossAttackSignal.value > 0
                      ? Text(
                              ctrl.bossAttackLabelKey.tr,
                              style: TextStyle(
                                fontFamily: 'Baloo2',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: barColor,
                                shadows: [
                                  Shadow(color: barColor, blurRadius: 12),
                                ],
                              ),
                            )
                            .animate(key: ValueKey(ctrl.bossAttackSignal.value))
                            .fadeIn(duration: 90.ms)
                            .shake(duration: 260.ms, hz: 8)
                            .fadeOut(delay: 350.ms, duration: 180.ms)
                      : const SizedBox.shrink(),
                ),
                // W23 — Flash khi boss LÊN phase mới ("PHASE 2!" / "PHASE 3!")
                Obx(
                  () => ctrl.bossPhaseUpSignal.value > 0
                      ? Text(
                              'PHASE ${ctrl.bossPhase + 1}!',
                              style: const TextStyle(
                                fontFamily: 'Baloo2',
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: NeonTheme.magenta,
                                shadows: [
                                  Shadow(
                                    color: NeonTheme.magenta,
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            )
                            .animate(
                              key: ValueKey(
                                'phaseup_${ctrl.bossPhaseUpSignal.value}',
                              ),
                            )
                            .fadeIn(duration: 120.ms)
                            .scale(
                              begin: const Offset(0.6, 0.6),
                              end: const Offset(1.15, 1.15),
                              duration: 360.ms,
                            )
                            .fadeOut(delay: 650.ms, duration: 250.ms)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// HUD chế độ Nhịp điệu (W21): 4-dot indicator + groove bar + judgment badge + BPM.
  Widget _rhythmHud(GameController ctrl) {
    final groove = ctrl.groove.value;
    // Màu accent theo groove: cyan (thấp) → lime (giữa) → yellow (cao)
    final accent = groove >= GameController.kGrooveMax
        ? NeonTheme.yellow
        : groove >= GameController.kGrooveMax ~/ 2
        ? NeonTheme.lime
        : NeonTheme.cyan;
    final badgeColor = ctrl.rhythmJudge.value == 2
        ? NeonTheme.yellow
        : ctrl.rhythmJudge.value == 1
        ? NeonTheme.lime
        : ctrl.rhythmJudge.value == -1
        ? NeonTheme.orange
        : NeonTheme.magenta;
    final badgeText = ctrl.rhythmJudge.value == 2
        ? 'PERFECT'
        : ctrl.rhythmJudge.value == 1
        ? 'GOOD'
        : ctrl.rhythmJudge.value == -1
        ? 'LATE'
        : ctrl.rhythmJudge.value == -2
        ? 'MISS'
        : '';

    return Padding(
      padding: const EdgeInsets.only(top: NeonTheme.s8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 4 dot nhịp — dot active = beat % 4
              Row(
                children: List.generate(4, (i) {
                  final active = ctrl.rhythmBeat.value % 4 == i;
                  final dotColor = active ? accent : Colors.white24;
                  return Container(
                        width: active ? 14 : 8,
                        height: active ? 14 : 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          boxShadow: active
                              ? [BoxShadow(color: accent, blurRadius: 10)]
                              : null,
                        ),
                      )
                      .animate(key: ValueKey('${ctrl.rhythmBeat.value}_$i'))
                      .scale(
                        begin: active
                            ? const Offset(1.4, 1.4)
                            : const Offset(1, 1),
                        end: const Offset(1, 1),
                        duration: 200.ms,
                        curve: Curves.easeOut,
                      );
                }),
              ),
              const SizedBox(width: 10),
              // thanh groove
              Row(
                children: List.generate(GameController.kGrooveMax, (i) {
                  final on = i < groove;
                  return Container(
                    width: 7,
                    height: 13,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: on ? accent : Colors.white12,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: on
                          ? [BoxShadow(color: accent, blurRadius: 5)]
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(width: 10),
              // BPM label
              Text(
                '${ctrl.rhythmBpm.value.toInt()} BPM',
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          // Judgment badge fly-up (key = rhythmJudge value → re-animate mỗi lần đánh)
          if (badgeText.isNotEmpty)
            Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                    shadows: [Shadow(color: badgeColor, blurRadius: 12)],
                  ),
                )
                .animate(
                  key: ValueKey(
                    '${ctrl.rhythmJudge.value}_${ctrl.rhythmBeat.value}',
                  ),
                )
                .fadeIn(duration: 120.ms)
                .slideY(begin: 0.3, end: 0, duration: 200.ms)
                .then()
                .fadeOut(delay: 300.ms, duration: 200.ms),
        ],
      ),
    );
  }

  Widget _infoPanel(GameController ctrl) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NeonTheme.cyan.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: NeonTheme.glow(NeonTheme.cyan, blur: 6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => _infoCell(
                'hud_score'.tr,
                _animValue(fmtNum(ctrl.score.value)),
                NeonTheme.cyan,
              ),
            ),
          ),
          _divider(),
          Expanded(
            child: Obx(
              () => ctrl.isEndless.value
                  ? _infoCell(
                      'hud_stage'.tr,
                      _animValue('${ctrl.endlessStage.value}'),
                      NeonTheme.lime,
                    )
                  : _infoCell(
                      ctrl.isZen.value ? 'hud_score'.tr : 'hud_goal'.tr,
                      _goalValue(ctrl),
                      NeonTheme.lime,
                    ),
            ),
          ),
          _divider(),
          Expanded(child: Obx(() => _movesOrTimeCell(ctrl))),
        ],
      ),
    );
  }

  /// Ô thứ 3 của HUD: Time Attack/Rush hiện TIME (mm:ss), còn lại MOVES.
  Widget _movesOrTimeCell(GameController ctrl) {
    // Sinh tồn "Triều dâng": hiện MỨC NGUY HIỂM nước dâng (%), đỏ khi ≥70%.
    if (ctrl.isSurvival.value) {
      final pct = (ctrl.tideLevel.value * 100).round();
      final urgent = ctrl.tideLevel.value >= 0.7;
      return _infoCell(
        'hud_tide'.tr,
        _animValue('$pct%'),
        urgent ? NeonTheme.magenta : NeonTheme.cyan,
      );
    }
    if (ctrl.isZen.value) {
      return _infoCell('zen_short'.tr, _animValue('∞'), NeonTheme.cyan);
    }
    if (ctrl.isGhostMode.value) {
      // Ghost mode: hiện điểm ghost để người chơi so sánh
      final gs = ctrl.ghostScore.value;
      return _infoCell('ghost_hud'.tr, _animValue(fmtNum(gs)), NeonTheme.cyan);
    }
    if (ctrl.level.objective == ObjectiveType.timeAttack || ctrl.isRush.value) {
      final t = ctrl.timeLeft.value;
      final urgent = ctrl.isRush.value ? t <= 15 : t <= 10;
      return _infoCell(
        'hud_time'.tr,
        _animValue(_fmtClock(t)),
        urgent ? NeonTheme.magenta : NeonTheme.orange,
      );
    }
    return _infoCell(
      'hud_moves'.tr,
      _animValue('${ctrl.movesLeft.value}'),
      NeonTheme.orange,
    );
  }

  String _fmtClock(int seconds) {
    final t = seconds.clamp(0, 1 << 30);
    final mm = (t ~/ 60).toString().padLeft(2, '0');
    final ss = (t % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _animatedBar(double progress) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Container(
        height: 8,
        decoration: BoxDecoration(
          color: NeonTheme.panel,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [NeonTheme.cyan, NeonTheme.lime],
                ),
                boxShadow: NeonTheme.glow(NeonTheme.lime, blur: 8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stageBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NeonTheme.purple, width: 2),
        boxShadow: NeonTheme.glow(NeonTheme.purple, blur: 8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          shadows: [Shadow(color: NeonTheme.purple, blurRadius: 10)],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1.2,
    height: 38,
    color: Colors.white.withValues(alpha: 0.12),
  );

  Widget _infoCell(String label, Widget value, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(fit: BoxFit.scaleDown, child: value),
        ),
      ],
    );
  }

  Widget _animValue(String v) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
    child: Text(v, key: ValueKey(v), style: _valueStyle),
  );

  Widget _goalValue(GameController ctrl) {
    // Zen: không có mục tiêu cố định — chỉ hiện điểm hiện tại (không có "/target")
    if (ctrl.isZen.value) {
      return Text(fmtNum(ctrl.score.value), style: _valueStyle);
    }
    final obj = ctrl.level.objective;
    // Order (Wave 10): nhiều mục tiêu màu cùng lúc → dãy chip nhỏ (dot + đếm),
    // FittedBox co vừa ô goal hẹp.
    if (obj == ObjectiveType.order) {
      final orders = ctrl.level.orders;
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (
              var i = 0;
              i < orders.length && i < ctrl.orderProgress.length;
              i++
            ) ...[
              if (i > 0) const SizedBox(width: 8),
              _orderChip(
                NeonTheme.gemColors[orders[i].color.index],
                ctrl.orderProgress[i],
                orders[i].target,
              ),
            ],
          ],
        ),
      );
    }
    Widget? leading;
    if (obj == ObjectiveType.collect && ctrl.level.collectColor != null) {
      final c = NeonTheme.gemColors[ctrl.level.collectColor!.index];
      leading = Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          boxShadow: NeonTheme.glow(c, blur: 6),
        ),
      );
    } else if (obj == ObjectiveType.clearJelly) {
      leading = const Padding(
        padding: EdgeInsets.only(right: 5),
        child: NeonIcon(Icons.blur_on_rounded, color: NeonTheme.lime, size: 15),
      );
    } else if (obj == ObjectiveType.dropDown) {
      leading = const Padding(
        padding: EdgeInsets.only(right: 5),
        child: NeonIcon(Icons.south_rounded, color: NeonTheme.lime, size: 15),
      );
    } else if (obj == ObjectiveType.clearObstacle) {
      leading = const Padding(
        padding: EdgeInsets.only(right: 5),
        child: NeonIcon(Icons.ac_unit_rounded, color: NeonTheme.cyan, size: 15),
      );
    } else if (obj == ObjectiveType.soda) {
      leading = const Padding(
        padding: EdgeInsets.only(right: 5),
        child: NeonIcon(
          Icons.local_drink_rounded,
          color: NeonTheme.cyan,
          size: 15,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?leading,
        Text(_objectiveText(ctrl), style: _valueStyle),
      ],
    );
  }

  /// 1 chip mục tiêu Order: chấm màu gem + "cur/target". Đạt đủ → viền lime.
  Widget _orderChip(Color color, int cur, int target) {
    final done = cur >= target;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: done ? Border.all(color: NeonTheme.lime, width: 1.5) : null,
            boxShadow: NeonTheme.glow(color, blur: 6),
          ),
        ),
        Text(
          '$cur/$target',
          style: TextStyle(
            color: done ? NeonTheme.lime : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static const TextStyle _valueStyle = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );

  // ---------------------------------------------------------------- Booster
  Widget _buildBoosterBar(GameController ctrl, GameScreenController sc) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s24,
        vertical: NeonTheme.s8,
      ),
      child: Row(
        children: [
          Obx(
            () =>
                _pill(
                      Icons.monetization_on_rounded,
                      NeonTheme.yellow,
                      fmtNum(ctrl.coins.value),
                    )
                    .animate(key: ValueKey(sc.coinShake.value))
                    .shake(duration: 450.ms, hz: 6),
          ),
          const SizedBox(width: NeonTheme.s16),
          // Swap: đổi 2 gem bất kỳ
          Obx(
            () => _armBooster(
              ctrl,
              sc,
              BoosterMode.swap,
              Icons.swap_horiz_rounded,
              NeonTheme.cyan,
              ctrl.boosterSwap.value,
              40,
              ctrl.buySwap,
            ),
          ),
          const SizedBox(width: NeonTheme.s8),
          // Búa: đập 1 gem
          Obx(
            () => _armBooster(
              ctrl,
              sc,
              BoosterMode.hammer,
              Icons.gavel_rounded,
              NeonTheme.orange,
              ctrl.boosterHammer.value,
              30,
              ctrl.buyHammer,
            ),
          ),
          const SizedBox(width: NeonTheme.s8),
          // Bom: nổ 3x3
          Obx(
            () => _armBooster(
              ctrl,
              sc,
              BoosterMode.bomb,
              Icons.adjust_rounded,
              NeonTheme.magenta,
              ctrl.boosterBomb.value,
              50,
              ctrl.buyBomb,
            ),
          ),
          const SizedBox(width: NeonTheme.s8),
          // Color Blast: xoá 1 màu
          Obx(
            () => _armBooster(
              ctrl,
              sc,
              BoosterMode.colorBlast,
              Icons.palette_rounded,
              NeonTheme.purple,
              ctrl.boosterColor.value,
              80,
              ctrl.buyColor,
            ),
          ),
          const SizedBox(width: NeonTheme.s8),
          // Joker: biến 1 gem thành Rainbow (arm)
          Obx(
            () => _armBooster(
              ctrl,
              sc,
              BoosterMode.joker,
              Icons.auto_awesome_rounded,
              NeonTheme.magenta,
              ctrl.boosterJoker.value,
              60,
              ctrl.buyJoker,
            ),
          ),
          const SizedBox(width: NeonTheme.s8),
          // Chain Lightning (tức thì)
          Obx(
            () => _instantBooster(
              ctrl,
              sc,
              Icons.bolt_rounded,
              NeonTheme.yellow,
              ctrl.boosterLightning.value,
              60,
              ctrl.useLightning,
              ctrl.buyLightning,
              () => sc.game.chainLightning(),
            ),
          ),
          const SizedBox(width: NeonTheme.s8),
          // Royal Flush (tức thì: nổ cả bàn)
          Obx(
            () => _instantBooster(
              ctrl,
              sc,
              Icons.workspace_premium_rounded,
              NeonTheme.orange,
              ctrl.boosterRoyal.value,
              120,
              ctrl.useRoyal,
              ctrl.buyRoyal,
              () => sc.game.royalFlush(),
            ),
          ),
          const SizedBox(width: NeonTheme.s8),
          // Gravity Flip (tức thì)
          Obx(
            () => _instantBooster(
              ctrl,
              sc,
              Icons.swap_vert_rounded,
              NeonTheme.cyan,
              ctrl.boosterGravity.value,
              50,
              ctrl.useGravity,
              ctrl.buyGravity,
              () => sc.game.gravityFlip(),
            ),
          ),
          const SizedBox(width: NeonTheme.s8),
          // +10 lượt (tức thì)
          Obx(
            () => _boosterBtn(
              Icons.av_timer_rounded,
              NeonTheme.lime,
              ctrl.boosterMoves.value,
              label: '+10',
              price: 40,
              onTap: () {
                dlog(
                  'MOVES tap count=${ctrl.boosterMoves.value} '
                  'moves=${ctrl.movesLeft.value} coins=${ctrl.coins.value}',
                );
                if (ctrl.boosterMoves.value > 0) {
                  ctrl.useMovesBooster();
                } else if (!ctrl.buyMoves()) {
                  sc.coinShake.value++;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Booster tức thì (lightning/royal/gravity): còn → dùng ngay; hết → mua.
  Widget _instantBooster(
    GameController ctrl,
    GameScreenController sc,
    IconData icon,
    Color color,
    int count,
    int price,
    bool Function() use,
    bool Function() buy,
    void Function() action,
  ) {
    return _boosterBtn(
      icon,
      color,
      count,
      price: price,
      onTap: () {
        dlog('instant booster count=$count coins=${ctrl.coins.value}');
        if (count > 0) {
          if (use()) action();
        } else if (!buy()) {
          sc.coinShake.value++;
        }
      },
    );
  }

  /// Booster cần chạm bàn (búa/swap/bom/color): chọn/bỏ chọn; hết → mua.
  Widget _armBooster(
    GameController ctrl,
    GameScreenController sc,
    BoosterMode mode,
    IconData icon,
    Color color,
    int count,
    int price,
    bool Function() buy,
  ) {
    final armed = sc.armed.value == mode;
    return _boosterBtn(
      icon,
      color,
      count,
      price: price,
      armed: armed,
      onTap: () {
        dlog(
          'booster $mode count=$count coins=${ctrl.coins.value} armed=$armed',
        );
        if (armed || count > 0) {
          sc.toggleArm(mode);
        } else if (!buy()) {
          sc.coinShake.value++;
        }
      },
    );
  }

  Widget _pill(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
        boxShadow: NeonTheme.glow(color, blur: 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Nút booster. Còn → "xN" (bấm để dùng); hết → giá mua (💰price).
  /// armed = true (búa đã chọn) → viền sáng + nền nổi bật.
  Widget _boosterBtn(
    IconData icon,
    Color color,
    int count, {
    required VoidCallback onTap,
    String? label,
    int price = 30,
    bool armed = false,
  }) {
    final has = count > 0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withValues(alpha: 0.4),
        highlightColor: color.withValues(alpha: 0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: armed
                ? color.withValues(alpha: 0.35)
                : NeonTheme.panel.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: armed ? 3 : 2),
            boxShadow: NeonTheme.glow(color, blur: armed ? 16 : 7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: armed ? Colors.white : color, size: 22),
              if (label != null) ...[
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              if (has)
                Text(
                  'x$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 13),
                    const SizedBox(width: 2),
                    Text(
                      fmtNum(price),
                      style: const TextStyle(
                        color: NeonTheme.yellow,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A fix: Ghost board overlay — hiện pulsing ring tại 2 ô ghost sẽ swap kế tiếp.
// Tọa độ Flame (boardOrigin, cellSize) tương đương logical pixel của GameWidget.
// ---------------------------------------------------------------------------

class _GhostHintOverlay extends StatefulWidget {
  final GameController ctrl;
  final GameScreenController sc;
  const _GhostHintOverlay({required this.ctrl, required this.sc});

  @override
  State<_GhostHintOverlay> createState() => _GhostHintOverlayState();
}

class _GhostHintOverlayState extends State<_GhostHintOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.55,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      widget.ctrl.ghostStep.value; // rebuild khi ghost step tiến
      final move = widget.ctrl.nextGhostMove();
      final game = widget.sc.game;
      // Guard: boardOrigin/cellSize là late fields — chờ _layout() xong
      if (move == null || !game.boardReady) return const SizedBox.shrink();
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context2, child2) => CustomPaint(
          painter: _GhostPainter(
            r1: move.$1,
            c1: move.$2,
            r2: move.$3,
            c2: move.$4,
            boardOriginX: game.boardOrigin.x,
            boardOriginY: game.boardOrigin.y,
            cellSize: game.cellSize,
            alpha: _pulse.value,
          ),
          child: const SizedBox.expand(),
        ),
      );
    });
  }
}

class _GhostPainter extends CustomPainter {
  final int r1, c1, r2, c2;
  final double boardOriginX, boardOriginY, cellSize, alpha;
  const _GhostPainter({
    required this.r1,
    required this.c1,
    required this.r2,
    required this.c2,
    required this.boardOriginX,
    required this.boardOriginY,
    required this.cellSize,
    required this.alpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NeonTheme.cyan.withValues(alpha: alpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    final glowPaint = Paint()
      ..color = NeonTheme.cyan.withValues(alpha: alpha * 0.25)
      ..style = PaintingStyle.fill;
    final r = cellSize * 0.44;
    for (final (row, col) in [(r1, c1), (r2, c2)]) {
      final cx = boardOriginX + col * cellSize + cellSize / 2;
      final cy = boardOriginY + row * cellSize + cellSize / 2;
      canvas.drawCircle(Offset(cx, cy), r, glowPaint);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_GhostPainter old) =>
      old.r1 != r1 ||
      old.c1 != c1 ||
      old.r2 != r2 ||
      old.c2 != c2 ||
      (old.alpha - alpha).abs() > 0.005; // 0.005 đủ nhỏ để không bỏ frame (~3ms)
}

/// W25.2 — Overlay mở-màn per-mode: tên mode + màu accent, fade+scale ngắn rồi
/// TỰ ẨN qua AnimationController (Ticker tự dispose khi unmount → KHÔNG để lại
/// Dart Timer pending trong widget test). Bọc IgnorePointer → không chặn chơi.
class _ModeIntroOverlay extends StatefulWidget {
  const _ModeIntroOverlay({
    required this.label,
    required this.accent,
    required this.reduced,
    required this.onDone,
  });
  final String label;
  final Color accent;
  final bool reduced;
  final VoidCallback onDone;

  @override
  State<_ModeIntroOverlay> createState() => _ModeIntroOverlayState();
}

class _ModeIntroOverlayState extends State<_ModeIntroOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1300),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // fade in [0,0.14] · giữ · fade out [0.86,1]
            final opacity = t < 0.14
                ? t / 0.14
                : (t > 0.86 ? (1 - t) / 0.14 : 1.0);
            final scale = widget.reduced
                ? 1.0
                : (t < 0.24 ? 0.72 + 0.28 * (t / 0.24) : 1.0);
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: NeonTheme.panel.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: widget.accent, width: 2.5),
                    boxShadow: NeonTheme.glow(widget.accent, blur: 22),
                  ),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [Shadow(color: widget.accent, blurRadius: 18)],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
