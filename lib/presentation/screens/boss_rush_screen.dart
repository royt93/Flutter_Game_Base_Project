import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../game/pop_star_game.dart';
import '../controllers/boss_rush_controller.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/neon_icon.dart';
import '../widgets/stroke_text.dart';

/// I43: giữ 1 [PopStarGame] duy nhất xuyên suốt cả chuỗi Boss Rush — khác
/// `GameScreen` (tạo lại game mỗi lần chơi lại/qua màn) vì
/// `PopStarGame._nextBossRushBoard` chỉ mutate grid tại chỗ để giữ nguyên
/// điểm/streak giữa các stage. Không tái dùng `GameScreenController` vì luồng
/// "thắng bàn → vào bàn kế ngay, không rời màn" không hợp mô hình "1 level
/// rồi điều hướng" của nó.
class BossRushScreen extends StatefulWidget {
  const BossRushScreen({super.key});

  @override
  State<BossRushScreen> createState() => _BossRushScreenState();
}

class _BossRushScreenState extends State<BossRushScreen> {
  final GameController _gameCtrl = Get.find<GameController>();
  late final BossRushController _brCtrl = Get.put(BossRushController());
  PopStarGame? _game;
  bool _confirmingQuit = false;

  @override
  void dispose() {
    Get.delete<BossRushController>();
    super.dispose();
  }

  void _startRun() {
    _brCtrl.startRun();
    setState(() => _game = PopStarGame(_gameCtrl));
  }

  void _quitRun() {
    setState(() => _confirmingQuit = false);
    _gameCtrl.checkEnd(false);
  }

  Vector2 _posOf(PointerEvent e) =>
      Vector2(e.localPosition.dx, e.localPosition.dy);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ended = _gameCtrl.ended.value;
      final playing = _game != null && !ended;
      return PopScope(
        canPop: !playing,
        child: Scaffold(
          body: NeonBg(
            child: Stack(
              children: [
                SafeArea(child: playing ? _buildPlay() : _buildLobby()),
                if (playing && _confirmingQuit)
                  NeonDialog.overlay(
                    onBarrier: () => setState(() => _confirmingQuit = false),
                    panel: NeonDialog.panel(
                      title: 'quit_title'.tr,
                      color: NeonTheme.red,
                      message: 'quit_msg'.tr,
                      actions: [
                        NeonDialogAction(
                          label: 'cancel'.tr,
                          color: NeonTheme.cyan,
                          onTap: () => setState(() => _confirmingQuit = false),
                        ),
                        NeonDialogAction(
                          label: 'quit_action'.tr,
                          color: NeonTheme.orange,
                          onTap: _quitRun,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLobby() {
    final showSummary = _game != null && _gameCtrl.ended.value;
    return Column(
      children: [
        NeonAppBar(title: 'boss_rush_title'.tr, color: NeonTheme.red),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(NeonTheme.s16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: NeonTheme.red,
                    size: 72,
                  ),
                  const SizedBox(height: NeonTheme.s16),
                  Obx(
                    () => StrokeText(
                      '${'boss_rush_best_streak_label'.tr}: '
                      '${_brCtrl.bossRushBestStreak.value}',
                      fontSize: 20,
                      color: NeonTheme.ink,
                      stroke: NeonTheme.red,
                    ),
                  ),
                  if (showSummary) ...[
                    const SizedBox(height: NeonTheme.s16),
                    StrokeText(
                      'boss_rush_run_over_title'.tr,
                      fontSize: 22,
                      color: NeonTheme.ink,
                      stroke: NeonTheme.magenta,
                    ),
                    const SizedBox(height: NeonTheme.s8),
                    Text(
                      '${'boss_rush_stages_cleared_label'.tr}: '
                      '${_brCtrl.lastStagesCleared}',
                      style: TextStyle(color: NeonTheme.ink, fontSize: 16),
                    ),
                    Text(
                      '${'boss_rush_coin_reward_label'.tr}: '
                      '+${_brCtrl.lastCoinReward}',
                      style: TextStyle(color: NeonTheme.ink, fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: NeonTheme.s24),
                  Container(
                    padding: const EdgeInsets.all(NeonTheme.s8),
                    decoration: BoxDecoration(
                      color: NeonTheme.cardAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'boss_rush_no_booster_notice'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NeonTheme.inkSoft, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: NeonTheme.s24),
                  NeonButton(
                    label: 'boss_rush_start_button'.tr,
                    color: NeonTheme.red,
                    onTap: _startRun,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlay() {
    final game = _game!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NeonTheme.s16,
            vertical: NeonTheme.s8,
          ),
          child: Row(
            children: [
              NeonIconButton(
                Icons.close_rounded,
                color: NeonTheme.cyan,
                onTap: () => setState(() => _confirmingQuit = true),
                semanticLabel: 'quit_button_label'.tr,
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(
                      () => StrokeText(
                        '${'boss_rush_stage_label'.tr} ${_brCtrl.stage.value}',
                        fontSize: 18,
                        color: NeonTheme.ink,
                        stroke: NeonTheme.red,
                      ),
                    ),
                    Obx(
                      () => Text(
                        '${_gameCtrl.score.value}',
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: Listener(
              onPointerDown: (e) => game.previewGroup(_posOf(e)),
              onPointerMove: (e) => game.previewGroup(_posOf(e)),
              onPointerUp: (e) {
                game.clearHint();
                game.clearPreview();
                game.handleTap(_posOf(e));
              },
              onPointerCancel: (_) => game.clearPreview(),
              child: GameWidget(
                game: game,
                backgroundBuilder: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
