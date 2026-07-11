import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../controllers/game_controller.dart';
import '../controllers/game_screen_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/coin_fly_overlay.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/neon_bg.dart';
import '../widgets/star_mascot.dart';
import '../widgets/stroke_text.dart';
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
        backgroundColor: NeonTheme.bgMid,
        body: NeonBg(
          child: SafeArea(
            child: Obx(() {
              gsc.gameVersion.value; // rebuild GameWidget khi đổi ván
              return Stack(
                children: [
                  Column(
                    children: [
                      _Hud(gsc: gsc, gameCtrl: gameCtrl),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Listener(
                            onPointerDown: (e) => gsc.previewBoardTap(
                              Vector2(e.localPosition.dx, e.localPosition.dy),
                            ),
                            onPointerMove: (e) => gsc.previewBoardTap(
                              Vector2(e.localPosition.dx, e.localPosition.dy),
                            ),
                            onPointerUp: (e) => gsc.handleBoardTap(
                              Vector2(e.localPosition.dx, e.localPosition.dy),
                            ),
                            onPointerCancel: (_) => gsc.game.clearPreview(),
                            child: GameWidget(
                              game: gsc.game,
                              backgroundBuilder: (_) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (gsc.ui.value == GameUi.win) ...[
                    const Positioned.fill(child: ConfettiOverlay()),
                    Positioned.fill(
                      child: CoinFlyOverlay(
                        key: ValueKey(gsc.gameVersion.value),
                      ),
                    ),
                  ],
                  if (gsc.ui.value != GameUi.playing) _Overlay(gsc: gsc),
                ],
              );
            }),
          ),
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
                  child: Obx(() {
                    final score = gameCtrl.score.value;
                    final target = gameCtrl.currentLevel.targetScore;
                    final reached = score >= target;
                    return Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: score.toDouble()),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          builder: (_, v, _) => StrokeText(
                            fmtNum(v.round()),
                            fontSize: 30,
                            color: NeonTheme.ink,
                            stroke: Colors.white,
                            strokeWidth: 4.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 190),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: (score / target).clamp(0.0, 1.0)),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            builder: (_, v, _) =>
                                _ProgressBar(value: v, reached: reached),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Target ${fmtNum(target)}',
                          style: const TextStyle(
                            color: NeonTheme.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                CoinChip(gameCtrl),
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
          color: armed ? color : NeonTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? color : const Color(0xFFC9C3DA),
            width: 2.5,
          ),
          boxShadow: enabled ? NeonTheme.drop(y: 3, blur: 6) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: armed
                  ? Colors.white
                  : (enabled ? color : const Color(0xFFC9C3DA)),
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: armed
                    ? Colors.white
                    : (enabled ? NeonTheme.ink : NeonTheme.inkSoft),
                fontWeight: FontWeight.w800,
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
          panel: _MascotDialog(
            mood: StarMood.happy,
            panel: NeonDialog.panel(
              title: 'Level Complete!',
              color: NeonTheme.yellow,
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
          ),
        );
      case GameUi.lose:
        return NeonDialog.overlay(
          panel: _MascotDialog(
            mood: StarMood.sad,
            panel: NeonDialog.panel(
              title: 'Board Stuck',
              color: NeonTheme.orange,
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
          ),
        );
      case GameUi.playing:
        return const SizedBox.shrink();
    }
  }
}

/// Thanh tiến trình tới target — đầy dần, đổi màu + glow khi đạt.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.reached});

  final double value;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final c = reached ? NeonTheme.lime : NeonTheme.cyan;
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.001, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(6),
              boxShadow: reached ? NeonTheme.glow(c, blur: 8) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mascot ngôi sao peek phía trên dialog thắng/thua.
class _MascotDialog extends StatelessWidget {
  const _MascotDialog({required this.mood, required this.panel});

  final StarMood mood;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarMascot(size: 104, mood: mood),
        Transform.translate(offset: const Offset(0, -16), child: panel),
      ],
    );
  }
}
