import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../core/audio_manager.dart';
import '../../core/neon_theme.dart';
import '../../data/levels.dart';
import '../../game/neon_jewel_game.dart' show BoosterMode;
import '../controllers/game_controller.dart';
import '../controllers/game_screen_controller.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/neon_icon.dart';

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
        body: Container(
          decoration: const BoxDecoration(gradient: NeonTheme.bgGradient),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildHud(ctrl, sc),
                    Expanded(
                      child: Obx(() {
                        final v = sc.gameVersion.value;
                        return GameWidget(key: ValueKey(v), game: sc.game);
                      }),
                    ),
                    _buildBoosterBar(ctrl, sc),
                    const SizedBox(height: NeonTheme.s8),
                  ],
                ),
              ),
              // Overlay dialog render TRÊN GameWidget (Flame không đè được)
              Obx(() => _overlay(ctrl, sc)),
            ],
          ),
        ),
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
                  onTap: sc.closeOverlay),
              NeonDialogAction(
                  label: 'confirm'.tr,
                  color: NeonTheme.magenta,
                  onTap: sc.quit),
            ],
          ),
        );
      case GameUi.win:
        return NeonDialog.overlay(panel: _resultPanel(ctrl, sc, true));
      case GameUi.lose:
        return NeonDialog.overlay(panel: _resultPanel(ctrl, sc, false));
    }
  }

  Widget _resultPanel(GameController ctrl, GameScreenController sc, bool win) {
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
              label: 'btn_again'.tr, color: NeonTheme.cyan, onTap: sc.again),
        if (win && cur < kLevels.length)
          NeonDialogAction(
              label: 'btn_next'.tr, color: NeonTheme.lime, onTap: sc.next)
        else
          NeonDialogAction(
              label: 'btn_home'.tr, color: NeonTheme.purple, onTap: sc.quit),
      ],
    );
  }

  String _objectiveText(GameController ctrl) {
    switch (ctrl.level.objective) {
      case ObjectiveType.score:
        return '${ctrl.score.value} / ${ctrl.targetScore.value}';
      case ObjectiveType.collect:
        return '${ctrl.collected.value} / ${ctrl.level.collectTarget}';
      case ObjectiveType.clearJelly:
        return '${ctrl.jellyCleared.value} / ${ctrl.jellyTotal.value}';
      case ObjectiveType.timeAttack:
        return '${ctrl.score.value} / ${ctrl.targetScore.value}';
      case ObjectiveType.dropDown:
        return '${ctrl.dropped.value} / ${ctrl.level.dropTarget}';
      case ObjectiveType.clearObstacle:
        return '${ctrl.obstacleCleared.value} / ${ctrl.obstacleTotal.value}';
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
              child: Icon(
                Icons.star_rounded,
                size: 42,
                color: on ? Colors.amber : Colors.white24,
                shadows: on
                    ? const [Shadow(color: Colors.amber, blurRadius: 18)]
                    : null,
              ).animate().scale(
                  delay: (i * 160).ms,
                  duration: 420.ms,
                  curve: Curves.elasticOut),
            );
          }),
        ),
        const SizedBox(height: NeonTheme.s8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on_rounded,
                color: NeonTheme.yellow, size: 20),
            const SizedBox(width: 6),
            Text('+${ctrl.lastCoinReward}',
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  color: NeonTheme.yellow,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                )),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------- HUD
  Widget _buildHud(GameController ctrl, GameScreenController sc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          NeonTheme.s24, NeonTheme.s16, NeonTheme.s24, NeonTheme.s8),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                NeonIconButton(Icons.close_rounded,
                    color: NeonTheme.magenta, size: 28, onTap: sc.confirmQuit),
                const Spacer(),
                Obx(() => _stageBadge(
                    'stage_n'.trParams({'n': '${ctrl.currentLevel.value}'}))),
                const Spacer(),
                if (AudioManager.maybe != null)
                  Obx(() => NeonIconButton(
                        AudioManager.maybe!.muted.value
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: NeonTheme.cyan,
                        size: 28,
                        onTap: AudioManager.maybe!.toggleMute,
                      ))
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          _infoPanel(ctrl),
          const SizedBox(height: NeonTheme.s8),
          Obx(() => _animatedBar(ctrl.objectiveProgress)),
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
        border:
            Border.all(color: NeonTheme.cyan.withValues(alpha: 0.4), width: 1.5),
        boxShadow: NeonTheme.glow(NeonTheme.cyan, blur: 6),
      ),
      child: Row(
        children: [
          Expanded(
              child: Obx(() => _infoCell('hud_score'.tr,
                  _animValue('${ctrl.score.value}'), NeonTheme.cyan))),
          _divider(),
          Expanded(
              child:
                  Obx(() => _infoCell('hud_goal'.tr, _goalValue(ctrl), NeonTheme.lime))),
          _divider(),
          Expanded(child: Obx(() => _movesOrTimeCell(ctrl))),
        ],
      ),
    );
  }

  /// Ô thứ 3 của HUD: Time Attack hiện TIME (mm:ss, đỏ khi ≤10s), còn lại MOVES.
  Widget _movesOrTimeCell(GameController ctrl) {
    if (ctrl.level.objective == ObjectiveType.timeAttack) {
      final t = ctrl.timeLeft.value;
      final mm = (t ~/ 60).toString().padLeft(2, '0');
      final ss = (t % 60).toString().padLeft(2, '0');
      final urgent = t <= 10;
      return _infoCell(
        'hud_time'.tr,
        _animValue('$mm:$ss'),
        urgent ? NeonTheme.magenta : NeonTheme.orange,
      );
    }
    return _infoCell(
        'hud_moves'.tr, _animValue('${ctrl.movesLeft.value}'), NeonTheme.orange);
  }

  Widget _animatedBar(double progress) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Container(
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
                    colors: [NeonTheme.cyan, NeonTheme.lime]),
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
      child: Text(text,
          style: const TextStyle(
            fontFamily: 'Orbitron',
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            shadows: [Shadow(color: NeonTheme.purple, blurRadius: 10)],
          )),
    );
  }

  Widget _divider() =>
      Container(width: 1.2, height: 38, color: Colors.white.withValues(alpha: 0.12));

  Widget _infoCell(String label, Widget value, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            )),
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
    final obj = ctrl.level.objective;
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
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) leading,
        Text(_objectiveText(ctrl), style: _valueStyle),
      ],
    );
  }

  static const TextStyle _valueStyle = TextStyle(
    fontFamily: 'Orbitron',
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );

  // ---------------------------------------------------------------- Booster
  Widget _buildBoosterBar(GameController ctrl, GameScreenController sc) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: NeonTheme.s24, vertical: NeonTheme.s8),
      child: Row(
        children: [
          Obx(() => _pill(Icons.monetization_on_rounded, NeonTheme.yellow,
                  '${ctrl.coins.value}')
              .animate(key: ValueKey(sc.coinShake.value))
              .shake(duration: 450.ms, hz: 6)),
          const SizedBox(width: NeonTheme.s16),
          // Swap: đổi 2 gem bất kỳ
          Obx(() => _armBooster(ctrl, sc, BoosterMode.swap,
              Icons.swap_horiz_rounded, NeonTheme.cyan,
              ctrl.boosterSwap.value, 40, ctrl.buySwap)),
          const SizedBox(width: NeonTheme.s8),
          // Búa: đập 1 gem
          Obx(() => _armBooster(ctrl, sc, BoosterMode.hammer,
              Icons.gavel_rounded, NeonTheme.orange,
              ctrl.boosterHammer.value, 30, ctrl.buyHammer)),
          const SizedBox(width: NeonTheme.s8),
          // Bom: nổ 3x3
          Obx(() => _armBooster(ctrl, sc, BoosterMode.bomb,
              Icons.adjust_rounded, NeonTheme.magenta,
              ctrl.boosterBomb.value, 50, ctrl.buyBomb)),
          const SizedBox(width: NeonTheme.s8),
          // Color Blast: xoá 1 màu
          Obx(() => _armBooster(ctrl, sc, BoosterMode.colorBlast,
              Icons.palette_rounded, NeonTheme.purple,
              ctrl.boosterColor.value, 80, ctrl.buyColor)),
          const SizedBox(width: NeonTheme.s8),
          // Joker: biến 1 gem thành Rainbow (arm)
          Obx(() => _armBooster(ctrl, sc, BoosterMode.joker,
              Icons.auto_awesome_rounded, NeonTheme.magenta,
              ctrl.boosterJoker.value, 60, ctrl.buyJoker)),
          const SizedBox(width: NeonTheme.s8),
          // Chain Lightning (tức thì)
          Obx(() => _instantBooster(ctrl, sc, Icons.bolt_rounded, NeonTheme.yellow,
              ctrl.boosterLightning.value, 60, ctrl.useLightning, ctrl.buyLightning,
              () => sc.game.chainLightning())),
          const SizedBox(width: NeonTheme.s8),
          // Royal Flush (tức thì: nổ cả bàn)
          Obx(() => _instantBooster(ctrl, sc, Icons.workspace_premium_rounded,
              NeonTheme.orange, ctrl.boosterRoyal.value, 120, ctrl.useRoyal,
              ctrl.buyRoyal, () => sc.game.royalFlush())),
          const SizedBox(width: NeonTheme.s8),
          // Gravity Flip (tức thì)
          Obx(() => _instantBooster(ctrl, sc, Icons.swap_vert_rounded,
              NeonTheme.cyan, ctrl.boosterGravity.value, 50, ctrl.useGravity,
              ctrl.buyGravity, () => sc.game.gravityFlip())),
          const SizedBox(width: NeonTheme.s8),
          // +10 lượt (tức thì)
          Obx(() => _boosterBtn(
                Icons.av_timer_rounded,
                NeonTheme.lime,
                ctrl.boosterMoves.value,
                label: '+10',
                price: 40,
                onTap: () {
                  debugPrint('roy93~ MOVES tap count=${ctrl.boosterMoves.value} '
                      'moves=${ctrl.movesLeft.value} coins=${ctrl.coins.value}');
                  if (ctrl.boosterMoves.value > 0) {
                    ctrl.useMovesBooster();
                  } else if (!ctrl.buyMoves()) {
                    sc.coinShake.value++;
                  }
                },
              )),
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
        debugPrint('roy93~ instant booster count=$count coins=${ctrl.coins.value}');
        if (count > 0) {
          if (use()) action();
        } else if (!buy()) {
          sc.coinShake.value++;
        }
      },
    );
  }

  /// Booster cần chạm bàn (búa/swap/bom/color): chọn/bỏ chọn; hết → mua.
  Widget _armBooster(GameController ctrl, GameScreenController sc, BoosterMode mode,
      IconData icon, Color color, int count, int price, bool Function() buy) {
    final armed = sc.armed.value == mode;
    return _boosterBtn(
      icon,
      color,
      count,
      price: price,
      armed: armed,
      onTap: () {
        debugPrint('roy93~ booster $mode count=$count coins=${ctrl.coins.value} armed=$armed');
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            )),
      ]),
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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: armed ? Colors.white : color, size: 22),
            if (label != null) ...[
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  )),
            ],
            const SizedBox(width: 6),
            if (has)
              Text('x$count',
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ))
            else
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.monetization_on_rounded,
                    color: NeonTheme.yellow, size: 13),
                const SizedBox(width: 2),
                Text('$price',
                    style: const TextStyle(
                      fontFamily: 'Orbitron',
                      color: NeonTheme.yellow,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    )),
              ]),
          ]),
        ),
      ),
    );
  }
}
