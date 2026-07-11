import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../controllers/game_controller.dart';
import '../controllers/game_screen_controller.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/neon_icon.dart';

/// Màn chơi: bàn Flame (tap-to-pop) + HUD điểm/booster + overlay thắng/thua.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gsc = Get.put(GameScreenController(Get.find<GameController>()));
    final gameCtrl = gsc.gameCtrl;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) gsc.confirmQuit();
      },
      child: Scaffold(
        backgroundColor: NeonTheme.bgDark,
        body: SafeArea(
          child: Obx(() {
            gsc.gameVersion.value; // rebuild GameWidget khi đổi ván
            return Stack(
              children: [
                Column(
                  children: [
                    _Hud(gsc: gsc, gameCtrl: gameCtrl),
                    Expanded(
                      child: GestureDetector(
                        onTapUp: (details) => gsc.handleBoardTap(
                          Vector2(
                            details.localPosition.dx,
                            details.localPosition.dy,
                          ),
                        ),
                        child: GameWidget(game: gsc.game),
                      ),
                    ),
                  ],
                ),
                if (gsc.ui.value != GameUi.playing) _Overlay(gsc: gsc),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  final GameScreenController gsc;
  final GameController gameCtrl;
  const _Hud({required this.gsc, required this.gameCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            NeonTheme.panel.withValues(alpha: 0.92),
            NeonTheme.panel.withValues(alpha: 0.0),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        NeonTheme.s8,
        NeonTheme.s8,
        NeonTheme.s8,
        NeonTheme.s16,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                NeonIconButton(
                  Icons.close_rounded,
                  color: NeonTheme.cyan,
                  onTap: gsc.confirmQuit,
                ),
                const SizedBox(width: NeonTheme.s8),
                Expanded(
                  child: Obx(
                    () => Column(
                      children: [
                        Text(
                          fmtNum(gameCtrl.score.value),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: NeonTheme.cyan, blurRadius: 14),
                            ],
                          ),
                        ),
                        Text(
                          'Target ${fmtNum(gameCtrl.currentLevel.targetScore)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: NeonTheme.s8),
            Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BoosterButton(
                    icon: Icons.dangerous_rounded,
                    color: NeonTheme.orange,
                    count: gameCtrl.bombCount.value,
                    armed: gsc.armed.value == BoosterMode.bomb,
                    onTap: gsc.toggleBombArm,
                  ),
                  const SizedBox(width: NeonTheme.s16),
                  _BoosterButton(
                    icon: Icons.shuffle_rounded,
                    color: NeonTheme.lime,
                    count: gameCtrl.shuffleCount.value,
                    armed: false,
                    onTap: gsc.useShuffle,
                  ),
                  const SizedBox(width: NeonTheme.s16),
                  _BoosterButton(
                    icon: Icons.undo_rounded,
                    color: NeonTheme.purple,
                    count: gameCtrl.undoCount.value,
                    armed: false,
                    onTap: gsc.useUndo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoosterButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final bool armed;
  final VoidCallback onTap;

  const _BoosterButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.armed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = count > 0;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: armed
              ? color.withValues(alpha: 0.3)
              : NeonTheme.panel.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: enabled ? color : Colors.grey, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? color : Colors.grey, size: 20),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  final GameScreenController gsc;
  const _Overlay({required this.gsc});

  @override
  Widget build(BuildContext context) {
    switch (gsc.ui.value) {
      case GameUi.quit:
        return NeonDialog.overlay(
          onBarrier: gsc.closeOverlay,
          panel: NeonDialog.panel(
            title: 'Quit Level?',
            color: NeonTheme.cyan,
            message: 'Your progress in this level will be lost.',
            actions: [
              NeonDialogAction(
                label: 'Cancel',
                color: NeonTheme.cyan,
                onTap: gsc.closeOverlay,
              ),
              NeonDialogAction(
                label: 'Quit',
                color: NeonTheme.orange,
                onTap: gsc.quit,
              ),
            ],
          ),
        );
      case GameUi.win:
        final gameCtrl = gsc.gameCtrl;
        return NeonDialog.overlay(
          panel: NeonDialog.panel(
            title: 'Level Complete!',
            color: NeonTheme.yellow,
            icon: Icons.emoji_events_rounded,
            message:
                'Score ${fmtNum(gameCtrl.score.value)} · ${gameCtrl.starsEarned.value} stars',
            actions: [
              NeonDialogAction(
                label: 'Retry',
                color: NeonTheme.cyan,
                onTap: gsc.again,
              ),
              NeonDialogAction(
                label: 'Next',
                color: NeonTheme.yellow,
                onTap: gsc.next,
              ),
            ],
          ),
        );
      case GameUi.lose:
        return NeonDialog.overlay(
          panel: NeonDialog.panel(
            title: 'Board Stuck',
            color: NeonTheme.orange,
            icon: Icons.block_rounded,
            message: 'No more groups to pop. Try again?',
            actions: [
              NeonDialogAction(
                label: 'Menu',
                color: NeonTheme.cyan,
                onTap: gsc.quit,
              ),
              NeonDialogAction(
                label: 'Retry',
                color: NeonTheme.orange,
                onTap: gsc.again,
              ),
            ],
          ),
        );
      case GameUi.playing:
        return const SizedBox.shrink();
    }
  }
}
