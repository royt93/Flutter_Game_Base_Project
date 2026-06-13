import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    _buildGame();
  }

  void _buildGame() {
    final lv = ctrl.level;
    game = NeonJewelGame(
      controller: ctrl,
      rows: lv.rows,
      cols: lv.cols,
      colorCount: lv.colorCount,
      onGameEnd: _onGameEnd,
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
        return '${ctrl.jellyCleared.value} / ${ctrl.jellyTotal}';
    }
  }

  void _showResultDialog(bool win) {
    final cur = ctrl.currentLevel.value;
    NeonDialog.show(
      title: win ? 'victory'.tr : 'retry'.tr,
      color: win ? NeonTheme.lime : NeonTheme.magenta,
      icon: win ? Icons.emoji_events_rounded : Icons.refresh_rounded,
      message: '${'hud_goal'.tr}: ${_objectiveText()}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: NeonTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHud(),
              Expanded(child: GameWidget(game: game)),
              const SizedBox(height: 8),
            ],
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
      padding: const EdgeInsets.fromLTRB(
          NeonTheme.s16, NeonTheme.s8, NeonTheme.s16, NeonTheme.s8),
      child: Column(
        children: [
          // Hàng trên gọn: đóng | stage | âm thanh
          SizedBox(
            height: 40,
            child: Row(
              children: [
                NeonIconButton(Icons.close_rounded,
                    color: NeonTheme.magenta, size: 22, onTap: _confirmQuit),
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
                        size: 22,
                        onTap: AudioManager.maybe!.toggleMute,
                      ))
                else
                  const SizedBox(width: 40),
              ],
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          // Hàng chip gọn inline — Flexible + FittedBox chống tràn
          Row(
            children: [
              Flexible(
                  child: Obx(() => _chip('hud_score'.tr, '${ctrl.score.value}',
                      NeonTheme.cyan))),
              const SizedBox(width: NeonTheme.s8),
              Flexible(child: Obx(() => _goalChip())),
              const SizedBox(width: NeonTheme.s8),
              Flexible(
                  child: Obx(() => _chip('hud_moves'.tr,
                      '${ctrl.movesLeft.value}', NeonTheme.orange))),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          Obx(() => _animatedBar(ctrl.objectiveProgress)),
        ],
      ),
    );
  }

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

  /// Chip inline gọn: nhãn + giá trị trên cùng 1 hàng (tự co bằng FittedBox).
  Widget _chip(String label, String value, Color color, {Widget? leading}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.8),
        boxShadow: NeonTheme.glow(color, blur: 6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
            const SizedBox(width: 5),
            if (leading != null) ...[leading, const SizedBox(width: 4)],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Text(
                value,
                key: ValueKey(value),
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalChip() {
    final obj = ctrl.level.objective;
    Widget? leading;
    if (obj == ObjectiveType.collect && ctrl.level.collectColor != null) {
      final c = NeonTheme.gemColors[ctrl.level.collectColor!.index];
      leading = Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          boxShadow: NeonTheme.glow(c, blur: 6),
        ),
      );
    } else if (obj == ObjectiveType.clearJelly) {
      leading =
          const NeonIcon(Icons.blur_on_rounded, color: NeonTheme.lime, size: 14);
    }
    return _chip('hud_goal'.tr, _objectiveText(), NeonTheme.lime,
        leading: leading);
  }
}
