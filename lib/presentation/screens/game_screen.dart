import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/levels.dart';
import '../controllers/game_controller.dart';
import '../controllers/game_screen_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/coin_fly_overlay.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/neon_aura_layer.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import '../widgets/pressable_scale.dart';
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
          energyOf: () => gsc.game.heat,
          child: SafeArea(
            child: Obx(() {
              gsc.gameVersion.value; // rebuild GameWidget khi đổi ván
              return Stack(
                children: [
                  Column(
                    children: [
                      _Hud(gsc: gsc, gameCtrl: gameCtrl),
                      Expanded(
                        child: Stack(
                          children: [
                            // G5: aura shader sau bàn, hoà vào nền sáng.
                            Positioned.fill(
                              child: NeonAuraLayer(
                                color: NeonTheme.cyan.withValues(alpha: 0.35),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.fromLTRB(
                                NeonTheme.s8,
                                0,
                                NeonTheme.s8,
                                NeonTheme.s16,
                              ),
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
                                  Vector2(
                                    e.localPosition.dx,
                                    e.localPosition.dy,
                                  ),
                                ),
                                onPointerMove: (e) => gsc.previewBoardTap(
                                  Vector2(
                                    e.localPosition.dx,
                                    e.localPosition.dy,
                                  ),
                                ),
                                onPointerUp: (e) => gsc.handleBoardTap(
                                  Vector2(
                                    e.localPosition.dx,
                                    e.localPosition.dy,
                                  ),
                                ),
                                onPointerCancel: (_) => gsc.game.clearPreview(),
                                child: GameWidget(
                                  game: gsc.game,
                                  backgroundBuilder: (_) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ],
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
                  Positioned.fill(child: _FlashOverlay(gameCtrl: gameCtrl)),
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
                    final scoreText = TweenAnimationBuilder<double>(
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
                    );
                    if (gameCtrl.mode.value == GameMode.timeAttack) {
                      return Column(
                        children: [
                          scoreText,
                          const SizedBox(height: NeonTheme.s8),
                          Text(
                            'Time ${gsc.remainingSeconds.value}s',
                            style: const TextStyle(
                              color: NeonTheme.inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    }
                    if (gameCtrl.mode.value == GameMode.zen) {
                      return Column(
                        children: [
                          scoreText,
                          const SizedBox(height: NeonTheme.s8),
                          const Text(
                            'Zen — no target',
                            style: TextStyle(
                              color: NeonTheme.inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    }
                    final target = gameCtrl.currentLevel.targetScore;
                    final reached = score >= target;
                    return Column(
                      children: [
                        scoreText,
                        const SizedBox(height: NeonTheme.s8),
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
                        const SizedBox(height: NeonTheme.s8),
                        Text(
                          'Target ${fmtNum(target)}',
                          style: const TextStyle(
                            color: NeonTheme.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        // F6b: màn có mục tiêu ngoài điểm (clear-color/
                        // clear-obstacle) hiện thêm dòng tiến độ riêng.
                        if (gameCtrl.currentLevel.objective.type !=
                            ObjectiveType.score) ...[
                          const SizedBox(height: NeonTheme.s8),
                          Text(
                            gameCtrl.currentLevel.objective.type ==
                                    ObjectiveType.clearColor
                                ? 'Clear color: ${gameCtrl.objectiveRemaining.value} left'
                                : 'Break ice: ${gameCtrl.objectiveRemaining.value} left',
                            style: const TextStyle(
                              color: NeonTheme.inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ),
                CoinChip(gameCtrl),
                const SizedBox(width: NeonTheme.s8),
                IgnorePointer(
                  child: Obx(
                    () => StarMascot(
                      size: 40,
                      mood: gameCtrl.comboMultiplier.value > 1.4
                          ? StarMood.cheer
                          : StarMood.idle,
                    ),
                  ),
                ),
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
                  const SizedBox(width: NeonTheme.s16),
                  _BoosterButton(
                    icon: Icons.auto_awesome_rounded,
                    color: NeonTheme.magenta,
                    count: gameCtrl.rainbowCount.value,
                    armed: gsc.armed.value == BoosterMode.rainbow,
                    onTap: gsc.toggleRainbowArm,
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

/// Flash trắng ngắn khi nổ nhóm lớn/combo cao (G2). Nghe [GameController.flashTick].
class _FlashOverlay extends StatelessWidget {
  const _FlashOverlay({required this.gameCtrl});
  final GameController gameCtrl;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Obx(() {
        final tick = gameCtrl.flashTick.value;
        if (tick == 0) return const SizedBox.shrink();
        return TweenAnimationBuilder<double>(
          key: ValueKey(tick),
          tween: Tween(begin: 0.18, end: 0.0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          builder: (_, v, _) =>
              Container(color: Colors.white.withValues(alpha: v)),
        );
      }),
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
    return PressableScale(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NeonTheme.s16,
          vertical: NeonTheme.s8,
        ),
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
            const SizedBox(width: NeonTheme.s8),
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
        return NeonDialog.overlay(panel: _WinChoreography(gsc: gsc));
      case GameUi.lose:
        final gameCtrl = gsc.gameCtrl;
        final isTimeAttack = gameCtrl.mode.value == GameMode.timeAttack;
        return NeonDialog.overlay(
          panel: _MascotDialog(
            mood: isTimeAttack ? StarMood.cheer : StarMood.sad,
            panel: NeonDialog.panel(
              title: isTimeAttack ? "Time's Up!" : 'Board Stuck',
              color: NeonTheme.orange,
              message: isTimeAttack
                  ? 'Score ${gameCtrl.score.value} — Best ${gameCtrl.timeAttackBest.value}'
                  : 'No more groups to pop. Try again?',
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

/// Chuỗi hiệu ứng thắng (A5): sao hiện lần lượt 1→2→3, rồi điểm đếm dần, rồi
/// nút bấm — tổng ~1.5-2s. Tap bất kỳ đâu trên panel để bỏ qua thẳng tới
/// trạng thái cuối (không kẹt nếu người chơi tap sớm).
class _WinChoreography extends StatefulWidget {
  const _WinChoreography({required this.gsc});
  final GameScreenController gsc;

  @override
  State<_WinChoreography> createState() => _WinChoreographyState();
}

class _WinChoreographyState extends State<_WinChoreography> {
  int _starsShown = 0;
  bool _scoreShown = false;
  bool _buttonsShown = false;
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    final stars = widget.gsc.gameCtrl.starsEarned.value;
    for (var i = 0; i < stars; i++) {
      _timers.add(
        Timer(Duration(milliseconds: 350 + i * 260), () {
          if (mounted) setState(() => _starsShown = i + 1);
        }),
      );
    }
    final afterStars = 350 + stars * 260;
    _timers.add(
      Timer(Duration(milliseconds: afterStars + 150), () {
        if (mounted) setState(() => _scoreShown = true);
      }),
    );
    _timers.add(
      Timer(Duration(milliseconds: afterStars + 650), () {
        if (mounted) setState(() => _buttonsShown = true);
      }),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _skip() {
    for (final t in _timers) {
      t.cancel();
    }
    setState(() {
      _starsShown = widget.gsc.gameCtrl.starsEarned.value;
      _scoreShown = true;
      _buttonsShown = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameCtrl = widget.gsc.gameCtrl;
    final stars = gameCtrl.starsEarned.value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: _MascotDialog(
        mood: StarMood.cheer,
        panel: NeonDialog.panel(
          title: 'Level Complete!',
          color: NeonTheme.yellow,
          actions: const [],
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < stars; i++) ...[
                    if (i > 0) const SizedBox(width: NeonTheme.s8),
                    AnimatedScale(
                      scale: i < _starsShown ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.elasticOut,
                      child: const Icon(
                        Icons.star_rounded,
                        color: NeonTheme.gold,
                        size: 36,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: NeonTheme.s8),
              AnimatedOpacity(
                opacity: _scoreShown ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    end: _scoreShown ? gameCtrl.score.value.toDouble() : 0,
                  ),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (_, v, _) => Text(
                    'Score ${fmtNum(v.round())}',
                    style: const TextStyle(
                      color: NeonTheme.inkSoft,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NeonTheme.s16),
              AnimatedOpacity(
                opacity: _buttonsShown ? 1 : 0,
                duration: const Duration(milliseconds: 240),
                child: IgnorePointer(
                  ignoring: !_buttonsShown,
                  child: Row(
                    children: [
                      Expanded(
                        child: NeonButton(
                          label: 'RETRY',
                          color: NeonTheme.cyan,
                          onTap: widget.gsc.again,
                        ),
                      ),
                      const SizedBox(width: NeonTheme.s16),
                      Expanded(
                        child: NeonButton(
                          label: 'NEXT',
                          color: NeonTheme.yellow,
                          onTap: widget.gsc.next,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
