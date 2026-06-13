import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/audio_manager.dart';
import '../../core/neon_theme.dart';
import '../../data/levels.dart';
import '../../game/neon_jewel_game.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/neon_icon.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameController ctrl = Get.find<GameController>();
  late NeonJewelGame game;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // giữ màn hình luôn sáng khi chơi
    _buildGame();
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // cho phép tắt màn khi rời game
    super.dispose();
  }

  void _buildGame() {
    final lv = ctrl.level;
    game = NeonJewelGame(
      controller: ctrl,
      rows: lv.rows,
      cols: lv.cols,
      colorCount: lv.colorCount,
      onGameEnd: _onGameEnd,
      onHammerUsed: ctrl.useHammer,
    );
  }

  void _onGameEnd(String result) {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _showResultDialog(result == 'win');
    });
  }

  String _objectiveText() {
    switch (ctrl.level.objective) {
      case ObjectiveType.score:
        return '${ctrl.score.value} / ${ctrl.targetScore.value}';
      case ObjectiveType.collect:
        return '${ctrl.collected.value} / ${ctrl.level.collectTarget}';
      case ObjectiveType.clearJelly:
        return '${ctrl.jellyCleared.value} / ${ctrl.jellyTotal.value}';
    }
  }

  void _showResultDialog(bool win) {
    final cur = ctrl.currentLevel.value;
    NeonDialog.show(
      title: win ? 'victory'.tr : 'retry'.tr,
      color: win ? NeonTheme.lime : NeonTheme.magenta,
      icon: win ? Icons.emoji_events_rounded : Icons.refresh_rounded,
      message: '${'hud_goal'.tr}: ${_objectiveText()}',
      content: win ? _celebration() : null,
      actions: [
        NeonDialogAction(
          label: 'btn_again'.tr,
          color: NeonTheme.cyan,
          onTap: () {
            ctrl.startLevel(cur);
            setState(_buildGame);
          },
        ),
        if (win && cur < kLevels.length)
          NeonDialogAction(
            label: 'btn_next'.tr,
            color: NeonTheme.lime,
            onTap: () {
              ctrl.startLevel(cur + 1);
              setState(_buildGame);
            },
          )
        else
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            onTap: Get.back,
          ),
      ],
    );
  }

  /// Nội dung celebration trong dialog thắng: sao bay + thưởng xu.
  Widget _celebration() {
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
              )
                  .animate()
                  .scale(
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

  Widget _buildBoosterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: NeonTheme.s24, vertical: NeonTheme.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // xu
          Obx(() => _pill(Icons.monetization_on_rounded, NeonTheme.yellow,
              '${ctrl.coins.value}')),
          const SizedBox(width: NeonTheme.s24),
          // búa: có thì kích hoạt, hết thì mua 30 xu
          Obx(() => _boosterBtn(
                Icons.gavel_rounded,
                NeonTheme.orange,
                ctrl.boosterHammer.value,
                () {
                  if (ctrl.boosterHammer.value > 0) {
                    game.armHammer();
                  } else {
                    ctrl.buyHammer();
                  }
                },
              )),
          const SizedBox(width: NeonTheme.s16),
          // xáo trộn
          Obx(() => _boosterBtn(
                Icons.shuffle_rounded,
                NeonTheme.purple,
                ctrl.boosterShuffle.value,
                () {
                  if (ctrl.useShuffleBooster()) {
                    game.shuffleBoard();
                  } else {
                    ctrl.buyShuffle();
                  }
                },
              )),
        ],
      ),
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

  /// Nút booster: icon + "xN" nếu còn, hoặc badge "+" (mua) nếu hết.
  Widget _boosterBtn(IconData icon, Color color, int count, VoidCallback onTap) {
    final has = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 2),
          boxShadow: NeonTheme.glow(color, blur: 7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
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
            const Icon(Icons.add_circle_rounded,
                color: NeonTheme.yellow, size: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // chặn back hệ thống → hiện dialog xác nhận thoát (như nút X)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: NeonTheme.bgGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildHud(),
                Expanded(child: GameWidget(game: game)),
                _buildBoosterBar(),
                const SizedBox(height: NeonTheme.s8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmQuit() {
    NeonDialog.show(
      title: 'quit_title'.tr,
      color: NeonTheme.magenta,
      icon: Icons.exit_to_app_rounded,
      message: 'quit_msg'.tr,
      dismissible: true,
      actions: [
        NeonDialogAction(
          label: 'cancel'.tr,
          color: NeonTheme.cyan,
          onTap: () {},
        ),
        NeonDialogAction(
          label: 'confirm'.tr,
          color: NeonTheme.magenta,
          onTap: Get.back, // rời màn chơi
        ),
      ],
    );
  }

  Widget _buildHud() {
    return Padding(
      // padding ngang lớn để nút X rời khỏi vùng vuốt-mép (gesture nav) → tap được
      padding: const EdgeInsets.fromLTRB(
          NeonTheme.s24, NeonTheme.s16, NeonTheme.s24, NeonTheme.s8),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                NeonIconButton(Icons.close_rounded,
                    color: NeonTheme.magenta, size: 28, onTap: _confirmQuit),
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
          _infoPanel(),
          const SizedBox(height: NeonTheme.s8),
          Obx(() => _animatedBar(ctrl.objectiveProgress)),
        ],
      ),
    );
  }

  /// Panel thông tin thống nhất: SCORE | GOAL | MOVES — cùng chiều cao, căn giữa.
  Widget _infoPanel() {
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
          Expanded(child: Obx(() => _infoCell('hud_goal'.tr, _goalValue(), NeonTheme.lime))),
          _divider(),
          Expanded(
              child: Obx(() => _infoCell('hud_moves'.tr,
                  _animValue('${ctrl.movesLeft.value}'), NeonTheme.orange))),
        ],
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

  Widget _goalValue() {
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
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) leading,
        Text(_objectiveText(), style: _valueStyle),
      ],
    );
  }

  final TextStyle _valueStyle = const TextStyle(
    fontFamily: 'Orbitron',
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );

  /// Thanh tiến độ animate mượt + glow.
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
        style: const TextStyle(
          fontFamily: 'Orbitron',
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          shadows: [Shadow(color: NeonTheme.purple, blurRadius: 10)],
        ),
      ),
    );
  }

}
