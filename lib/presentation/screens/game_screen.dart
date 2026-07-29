import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../core/utils/format.dart';
import '../../data/combo_text_styles.dart';
import '../../data/levels.dart';
import '../../data/mascot_skins.dart';
import '../../data/worlds.dart';
import '../../game/pop_star_game.dart';
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
          // X8: side-mode (Zen/TimeAttack/Endless/Daily) dùng id âm —
          // worldForLevel không match world nào nên bỏ qua, tránh ăn nhầm
          // theme world cuối (I16 aurora chỉ dành world khó nhất thật sự).
          accent: gameCtrl.currentLevel.id > 0
              ? worldForLevel(gameCtrl.currentLevel.id).color
              : null,
          aurora:
              gameCtrl.currentLevel.id > 0 &&
              worldForLevel(gameCtrl.currentLevel.id) == kWorlds.last,
          weather: gameCtrl.currentLevel.id > 0
              ? worldForLevel(gameCtrl.currentLevel.id).weather
              : WeatherKind.none,
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
                            RepaintBoundary(
                              key: gsc.boardKey,
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(
                                  NeonTheme.s8,
                                  0,
                                  NeonTheme.s8,
                                  NeonTheme.s16,
                                ),
                                // I51: khung viền board cosmetic, thuần
                                // trang trí — không ảnh hưởng gameplay.
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: gameCtrl.activeBoardFrame.color,
                                    width: 3,
                                  ),
                                  boxShadow: NeonTheme.glow(
                                    gameCtrl.activeBoardFrame.color,
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
                                  onPointerCancel: (_) =>
                                      gsc.game.clearPreview(),
                                  child: GameWidget(
                                    game: gsc.game,
                                    backgroundBuilder: (_) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                            _FtueOverlay(gsc: gsc),
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
                  Positioned.fill(
                    child: _ComboMilestoneOverlay(gameCtrl: gameCtrl),
                  ),
                  Positioned.fill(
                    child: _AchievementUnlockOverlay(gameCtrl: gameCtrl),
                  ),
                  _Overlay(gsc: gsc),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// F6b/F9: dòng tiến độ mục tiêu hiện dưới HUD điểm — `null` cho `score`.
String? _objectiveLine(GameController gameCtrl) {
  final objective = gameCtrl.currentLevel.objective;
  final left = gameCtrl.objectiveRemaining.value;
  return switch (objective.type) {
    ObjectiveType.score => null,
    ObjectiveType.clearColor => 'obj_clear_color'.trParams({'left': '$left'}),
    ObjectiveType.clearObstacle => 'obj_break_ice'.trParams({'left': '$left'}),
    ObjectiveType.collect => 'obj_collect'.trParams({'left': '$left'}),
    ObjectiveType.obstacleInMoves =>
      '${'obj_break_ice'.trParams({'left': '$left'})} '
          '${'obj_bonus_star_moves'.trParams({'moves': '${objective.moveLimit}'})}',
    ObjectiveType.moveLimitBonus => 'obj_finish_bonus_star'.trParams({
      'moves': '${objective.moveLimit}',
    }),
    ObjectiveType.openGift => 'obj_open_gift'.trParams({'left': '$left'}),
  };
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
                  semanticLabel: 'quit_button_label'.tr,
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
                            '${'hud_time'.tr} ${gsc.remainingSeconds.value}s',
                            style: TextStyle(
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
                          Text(
                            'zen_no_target'.tr,
                            style: TextStyle(
                              color: NeonTheme.inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    }
                    if (gameCtrl.mode.value == GameMode.endless) {
                      return Column(
                        children: [
                          scoreText,
                          const SizedBox(height: NeonTheme.s8),
                          Text(
                            '${'endless_best'.tr} ${gameCtrl.endlessBest.value}',
                            style: TextStyle(
                              color: NeonTheme.inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    }
                    if (gameCtrl.mode.value == GameMode.mirrorMode) {
                      return Column(
                        children: [
                          scoreText,
                          const SizedBox(height: NeonTheme.s8),
                          Text(
                            '${'endless_best'.tr} ${gameCtrl.mirrorModeBest.value}',
                            style: TextStyle(
                              color: NeonTheme.inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    }
                    if (gameCtrl.mode.value == GameMode.dailyChallenge) {
                      return Column(
                        children: [
                          scoreText,
                          const SizedBox(height: NeonTheme.s8),
                          Text(
                            'daily_challenge_label'.tr,
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
                          'game_target_label'.trParams({
                            'target': fmtNum(target),
                          }),
                          style: TextStyle(
                            color: NeonTheme.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        // I49: badge màu may mắn của ngày — chỉ hiện ở
                        // campaign (nơi ×1.2 điểm áp dụng), không hiện ở
                        // puzzleLab/bossRush dù chúng dùng chung layout này.
                        if (gameCtrl.mode.value == GameMode.campaign) ...[
                          const SizedBox(height: NeonTheme.s8),
                          _LuckyColorBadge(gameCtrl: gameCtrl),
                        ],
                        // F6b/F9: màn có mục tiêu ngoài điểm hiện thêm dòng
                        // tiến độ riêng (moveLimitBonus không có "còn lại" —
                        // chỉ hiện giới hạn lượt cho bonus sao).
                        if (_objectiveLine(gameCtrl) case final line?) ...[
                          const SizedBox(height: NeonTheme.s8),
                          Text(
                            line,
                            style: TextStyle(
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
                      mood: moodForCombo(gameCtrl.comboCount.value),
                      palette: gameCtrl.activeMascotSkin.palette,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NeonTheme.s8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Obx(
                () => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _BoosterButton(
                      icon: Icons.dangerous_rounded,
                      color: NeonTheme.orange,
                      count: gameCtrl.bombCount.value,
                      armed: gsc.armed.value == BoosterMode.bomb,
                      onTap: gsc.toggleBombArm,
                      label: 'booster_bomb_label'.tr,
                    ),
                    const SizedBox(width: NeonTheme.s16),
                    _BoosterButton(
                      icon: Icons.shuffle_rounded,
                      color: NeonTheme.lime,
                      count: gameCtrl.shuffleCount.value,
                      armed: false,
                      onTap: gsc.useShuffle,
                      label: 'shuffle'.tr,
                    ),
                    const SizedBox(width: NeonTheme.s16),
                    _BoosterButton(
                      icon: Icons.undo_rounded,
                      color: NeonTheme.purple,
                      count: gameCtrl.undoCount.value,
                      armed: false,
                      onTap: gsc.useUndo,
                      label: 'booster_undo_label'.tr,
                      forceEnabled:
                          gameCtrl.undoCount.value > 0 || gameCtrl.hasFreeUndo,
                    ),
                    const SizedBox(width: NeonTheme.s16),
                    _BoosterButton(
                      icon: Icons.auto_awesome_rounded,
                      color: NeonTheme.magenta,
                      count: gameCtrl.rainbowCount.value,
                      armed: gsc.armed.value == BoosterMode.rainbow,
                      onTap: gsc.toggleRainbowArm,
                      label: 'booster_rainbow_label'.tr,
                    ),
                    const SizedBox(width: NeonTheme.s16),
                    _BoosterButton(
                      icon: Icons.swap_horiz_rounded,
                      color: NeonTheme.lime,
                      count: gameCtrl.swapCount.value,
                      armed: gsc.armed.value == BoosterMode.swap,
                      onTap: gsc.toggleSwapArm,
                      label: 'booster_swap_label'.tr,
                    ),
                    const SizedBox(width: NeonTheme.s16),
                    _BoosterButton(
                      icon: Icons.ac_unit_rounded,
                      color: NeonTheme.cyan,
                      count: gameCtrl.freezeCount.value,
                      armed: false,
                      onTap: gsc.useFreeze,
                      label: 'booster_freeze_label'.tr,
                    ),
                    const SizedBox(width: NeonTheme.s16),
                    _BoosterButton(
                      icon: Icons.lightbulb_rounded,
                      color: NeonTheme.yellow,
                      count: gameCtrl.hintCount.value,
                      armed: false,
                      onTap: gsc.useHint,
                      label: 'booster_hint_label'.tr,
                    ),
                  ],
                ),
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

/// I39: text "COMBO x{N}!" bay lên khi chạm mốc combo cố định. Nghe
/// [GameController.comboMilestoneTick]; animation tắt khi bật "giảm chuyển
/// động" nhưng haptic tương ứng ở [PopStarGame] vẫn chạy độc lập.
class _ComboMilestoneOverlay extends StatelessWidget {
  const _ComboMilestoneOverlay({required this.gameCtrl});
  final GameController gameCtrl;

  bool get _reduceMotion => StorageService.to.getBool(StorageKeys.reduceMotion);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Obx(() {
        final tick = gameCtrl.comboMilestoneTick.value;
        if (tick == 0 || _reduceMotion) return const SizedBox.shrink();
        final milestone = gameCtrl.comboMilestoneValue;
        final styleKind = gameCtrl.activeComboTextStyleKind.value;
        return Align(
          alignment: const Alignment(0, -0.3),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(tick),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (_, t, child) {
              final rise = -_comboTextRise(styleKind) * t;
              final fade = t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;
              final scale = styleKind == ComboTextStyleKind.boldPop
                  ? 0.7 + 0.3 * Curves.elasticOut.transform(t)
                  : 1.0;
              return Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, rise),
                  child: Transform.scale(scale: scale, child: child),
                ),
              );
            },
            child: _comboMilestoneText(
              styleKind,
              'combo_milestone_label'.trParams({'count': '$milestone'}),
            ),
          ),
        );
      }),
    );
  }
}

/// I54: khoảng nảy lên khác nhau theo style — Bold Pop nảy mạnh hơn Neon.
double _comboTextRise(ComboTextStyleKind kind) => switch (kind) {
  ComboTextStyleKind.boldPop => 56.0,
  ComboTextStyleKind.neon ||
  ComboTextStyleKind.retro ||
  ComboTextStyleKind.fire => 40.0,
};

/// I54: text combo-milestone theo style đang chọn — chỉ đổi hiển thị, không
/// đụng ngưỡng/haptic (`lib/data/combo_milestones.dart`).
Widget _comboMilestoneText(ComboTextStyleKind kind, String label) {
  switch (kind) {
    case ComboTextStyleKind.neon:
      return StrokeText(
        label,
        fontSize: 34,
        color: NeonTheme.ink,
        stroke: Colors.white,
        strokeWidth: 4,
      );
    case ComboTextStyleKind.boldPop:
      return StrokeText(
        label,
        fontSize: 46,
        color: NeonTheme.gold,
        stroke: NeonTheme.magenta,
        strokeWidth: 6,
      );
    case ComboTextStyleKind.retro:
      return StrokeText(
        label,
        fontSize: 30,
        color: NeonTheme.lime,
        stroke: NeonTheme.indigo,
        strokeWidth: 3,
        letterSpacing: 3,
      );
    case ComboTextStyleKind.fire:
      return _FireComboText(label);
  }
}

/// I54: style "Fire" — chữ tô gradient lửa (vàng→cam→đỏ) trên viền nâu sẫm.
class _FireComboText extends StatelessWidget {
  const _FireComboText(this.text);
  final String text;

  static const _style = TextStyle(fontSize: 34, fontWeight: FontWeight.w900);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: _style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF7A1E00),
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFF176), Color(0xFFFF9800), Color(0xFFE53935)],
          ).createShader(bounds),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: _style.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// I22: dialog ăn mừng khi vừa mở khoá thành tựu — tự dọn [GameController.
/// justUnlockedAchievement] sau khi hiện để không lặp lại.
class _AchievementUnlockOverlay extends StatelessWidget {
  const _AchievementUnlockOverlay({required this.gameCtrl});
  final GameController gameCtrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final a = gameCtrl.justUnlockedAchievement.value;
      return NeonDialog.overlaySlot(
        onBarrier: () => gameCtrl.justUnlockedAchievement.value = null,
        panelKey: a?.id,
        panel: a == null
            ? null
            : NeonDialog.panel(
                title: 'achievement_unlocked_title'.tr,
                color: NeonTheme.gold,
                icon: Icons.emoji_events_rounded,
                message:
                    '${a.titleKey.tr}\n${a.descKey.tr}\n+${a.coinReward} 🪙',
                actions: [
                  NeonDialogAction(
                    label: 'ok'.tr,
                    color: NeonTheme.gold,
                    onTap: () => gameCtrl.justUnlockedAchievement.value = null,
                  ),
                ],
              ),
      );
    });
  }
}

/// X1: banner "chạm để nổ" trỏ vào nhóm đang được [PopStarGame.triggerFtueHint]
/// tô sáng — chỉ hiện lần mở app đầu tiên trên level 1, không chặn tap.
/// ponytail: banner từng đóng cứng ở Alignment(0,-0.2), không liên quan gì
/// tới vị trí group thật đang được `_hint` trỏ tới — trên board nhiều hàng,
/// group có thể nằm ở nửa dưới trong khi banner luôn hiện ở nửa trên (đè lên
/// ô không liên quan). Đặt banner ở nửa bàn KHÔNG chứa group để không đè lên
/// group và không lạc quá xa nó.
double _ftueAlignY(PopStarGame game) {
  final hint = game.hintGroup;
  if (hint.isEmpty || game.rows <= 1) return -0.2;
  final avgRow = hint.map((p) => p.x).reduce((a, b) => a + b) / hint.length;
  final rowFrac = avgRow / (game.rows - 1); // 0 = hàng đầu .. 1 = hàng cuối
  return rowFrac < 0.5 ? 0.55 : -0.55;
}

class _FtueOverlay extends StatelessWidget {
  const _FtueOverlay({required this.gsc});
  final GameScreenController gsc;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!gsc.showFtue.value) return const SizedBox.shrink();
      return IgnorePointer(
        child: Align(
          alignment: Alignment(0, _ftueAlignY(gsc.game)),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: NeonTheme.s16,
              vertical: NeonTheme.s8,
            ),
            decoration: BoxDecoration(
              color: NeonTheme.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: NeonTheme.drop(y: 3, blur: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BouncingHand(),
                const SizedBox(width: NeonTheme.s8),
                Text(
                  'ftue_tap_hint'.tr,
                  style: TextStyle(
                    color: NeonTheme.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _BouncingHand extends StatefulWidget {
  const _BouncingHand();

  @override
  State<_BouncingHand> createState() => _BouncingHandState();
}

class _BouncingHandState extends State<_BouncingHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, 4 * _c.value), child: child),
      child: const Icon(
        Icons.touch_app_rounded,
        color: NeonTheme.cyan,
        size: 20,
      ),
    );
  }
}

/// I49: chip nhỏ báo màu may mắn của ngày (pop trúng màu này ×1.2 điểm).
class _LuckyColorBadge extends StatelessWidget {
  const _LuckyColorBadge({required this.gameCtrl});
  final GameController gameCtrl;

  @override
  Widget build(BuildContext context) {
    final color = NeonTheme
        .gemColors[gameCtrl.luckyColorIndex.value % NeonTheme.gemColors.length];
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: NeonTheme.glow(color, blur: 4),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'lucky_color_label'.tr,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
  final String label;
  final bool? forceEnabled;

  const _BoosterButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.armed,
    required this.onTap,
    required this.label,
    this.forceEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = forceEnabled ?? count > 0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: armed
          ? 'booster_count_armed_label'.trParams({
              'label': label,
              'count': '$count',
            })
          : 'booster_count_label'.trParams({'label': label, 'count': '$count'}),
      child: PressableScale(
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
              TweenAnimationBuilder<double>(
                tween: Tween(end: count.toDouble()),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                builder: (_, v, _) => Text(
                  '${v.round()}',
                  style: TextStyle(
                    color: armed
                        ? Colors.white
                        : (enabled ? NeonTheme.ink : NeonTheme.inkSoft),
                    fontWeight: FontWeight.w800,
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

class _Overlay extends StatelessWidget {
  final GameScreenController gsc;
  const _Overlay({required this.gsc});

  @override
  Widget build(BuildContext context) {
    final ui = gsc.ui.value;
    return Positioned.fill(
      child: NeonDialog.overlaySlot(
        panel: _buildFor(ui),
        panelKey: ui,
        onBarrier: ui == GameUi.quit ? gsc.closeOverlay : null,
      ),
    );
  }

  Widget? _buildFor(GameUi ui) {
    switch (ui) {
      case GameUi.quit:
        return NeonDialog.panel(
          title: 'quit_title'.tr,
          color: NeonTheme.cyan,
          message: 'quit_msg'.tr,
          actions: [
            NeonDialogAction(
              label: 'cancel'.tr,
              color: NeonTheme.cyan,
              onTap: gsc.closeOverlay,
            ),
            NeonDialogAction(
              label: 'quit_action'.tr,
              color: NeonTheme.orange,
              onTap: gsc.quit,
            ),
          ],
        );
      case GameUi.win:
        return _WinChoreography(gsc: gsc);
      case GameUi.lose:
        final gameCtrl = gsc.gameCtrl;
        final isTimeAttack = gameCtrl.mode.value == GameMode.timeAttack;
        final isEndless = gameCtrl.mode.value == GameMode.endless;
        final isDailyChallenge = gameCtrl.mode.value == GameMode.dailyChallenge;
        final isPuzzleLab = gameCtrl.mode.value == GameMode.puzzleLab;
        return _MascotDialog(
          mood: isPuzzleLab
              ? StarMood.cheer
              : (isTimeAttack ? StarMood.cheer : StarMood.sad),
          palette: gameCtrl.activeMascotSkin.palette,
          panel: NeonDialog.panel(
            title: isPuzzleLab
                ? 'puzzle_lab_result_title'.tr
                : (isTimeAttack ? 'time_up_title'.tr : 'board_stuck_title'.tr),
            color: NeonTheme.orange,
            message: isPuzzleLab
                ? 'puzzle_lab_score_label'.trParams({
                    'score': '${gameCtrl.score.value}',
                  })
                : isTimeAttack
                ? 'score_best_label'.trParams({
                    'score': '${gameCtrl.score.value}',
                    'best': '${gameCtrl.timeAttackBest.value}',
                  })
                : isEndless
                ? 'score_best_label'.trParams({
                    'score': '${gameCtrl.score.value}',
                    'best': '${gameCtrl.endlessBest.value}',
                  })
                : isDailyChallenge
                ? 'score_recorded_label'.trParams({
                    'score': '${gameCtrl.score.value}',
                    'recorded': '${gameCtrl.dailyChallengeScoreToday}',
                  })
                : 'no_moves_retry_msg'.tr,
            // I37 Async Challenge Code: hiện kết quả so điểm thách đấu dù
            // màn kết thúc thắng/thua bình thường — chỉ campaign mới có
            // activeChallenge (startChallenge luôn gọi startLevel).
            content: gameCtrl.activeChallenge.value != null
                ? _challengeResultBanner(gameCtrl)
                : null,
            actions: [
              NeonDialogAction(
                label: 'menu'.tr,
                color: NeonTheme.cyan,
                onTap: gsc.quit,
              ),
              NeonDialogAction(
                label: 'retry'.tr,
                color: NeonTheme.orange,
                onTap: gsc.again,
              ),
            ],
          ),
        );
      case GameUi.playing:
        return null;
    }
  }
}

/// I32 Craft Booster: icon/màu/nhãn hiển thị theo loại booster quy đổi được
/// — mirror đúng icon/màu của [_BoosterButton] tương ứng trong HUD.
IconData _craftBoosterIcon(String type) => switch (type) {
  'bomb' => Icons.dangerous_rounded,
  'shuffle' => Icons.shuffle_rounded,
  _ => Icons.undo_rounded,
};

Color _craftBoosterColor(String type) => switch (type) {
  'bomb' => NeonTheme.orange,
  'shuffle' => NeonTheme.lime,
  _ => NeonTheme.purple,
};

String _craftBoosterLabel(String type) => switch (type) {
  'bomb' => 'booster_bomb_label'.tr,
  'shuffle' => 'shuffle'.tr,
  _ => 'booster_undo_label'.tr,
};

/// I37 Async Challenge Code: banner so điểm với [GameController.activeChallenge]
/// — dùng chung ở cả overlay thắng và thua vì kết quả thách đấu độc lập với
/// sao/coin bình thường (xem [GameController.checkEnd]).
Widget _challengeResultBanner(GameController gameCtrl) {
  final challenge = gameCtrl.activeChallenge.value!;
  final won = gameCtrl.challengeWon.value ?? false;
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: NeonTheme.s16,
      vertical: NeonTheme.s8,
    ),
    decoration: BoxDecoration(
      color: (won ? NeonTheme.lime : NeonTheme.orange).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      (won ? 'challenge_result_win_label' : 'challenge_result_lose_label')
          .trParams({
            'sender': challenge.senderName,
            'score': '${challenge.score}',
          }),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: won ? NeonTheme.lime : NeonTheme.orange,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
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
        palette: gameCtrl.activeMascotSkin.palette,
        panel: NeonDialog.panel(
          // F11: boss level thắng → nhãn riêng biệt với level thường.
          title: gameCtrl.currentLevel.isBoss
              ? 'boss_cleared_title'.tr
              : 'level_complete_title'.tr,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        end: _scoreShown ? gameCtrl.score.value.toDouble() : 0,
                      ),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (_, v, _) => Text(
                        'score_value_label'.trParams({
                          'score': fmtNum(v.round()),
                        }),
                        style: TextStyle(
                          color: NeonTheme.inkSoft,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    // F15: chia sẻ ảnh bàn chơi + level/điểm/ngày.
                    NeonIconButton(
                      Icons.share_rounded,
                      color: NeonTheme.cyan,
                      size: 20,
                      onTap: widget.gsc.shareBoard,
                      semanticLabel: 'share_board'.tr,
                    ),
                    // I28: chỉ hiện khi có replay hợp lệ để chia sẻ.
                    if (widget.gsc.canShareReplay) ...[
                      const SizedBox(width: NeonTheme.s8),
                      NeonIconButton(
                        Icons.movie_creation_rounded,
                        color: NeonTheme.magenta,
                        size: 20,
                        onTap: widget.gsc.shareReplay,
                        semanticLabel: 'share_replay'.tr,
                      ),
                    ],
                    // I37: thách đấu bạn bè bằng đúng điểm vừa đạt.
                    const SizedBox(width: NeonTheme.s8),
                    NeonIconButton(
                      Icons.emoji_events_rounded,
                      color: NeonTheme.gold,
                      size: 20,
                      onTap: widget.gsc.shareChallenge,
                      semanticLabel: 'share_challenge'.tr,
                    ),
                  ],
                ),
              ),
              // I37 Async Challenge Code: hiện kết quả so điểm thách đấu dù
              // thắng/thua — độc lập với sao/coin bình thường.
              if (gameCtrl.activeChallenge.value != null) ...[
                const SizedBox(height: NeonTheme.s8),
                AnimatedOpacity(
                  opacity: _scoreShown ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: _challengeResultBanner(gameCtrl),
                ),
              ],
              // Task #5: badge Perfect Clear — chỉ hiện khi thắng thử thách
              // vượt best score, dùng chung choreography opacity với score.
              if (gameCtrl.perfectClearSuccess.value) ...[
                const SizedBox(height: NeonTheme.s8),
                AnimatedOpacity(
                  opacity: _scoreShown ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    'perfect_clear_success_label'.trParams({
                      'coin': '${GameController.perfectClearBonusCoins}',
                    }),
                    style: const TextStyle(
                      color: NeonTheme.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              // I32 Craft Booster: bàn còn sót gem đủ ngưỡng craft point khi
              // thắng (không full-clear) → hiện "+1 <booster>"; ẩn hoàn toàn
              // nếu không có craft reward.
              if (gameCtrl.craftRewardType.value != null) ...[
                const SizedBox(height: NeonTheme.s8),
                AnimatedOpacity(
                  opacity: _scoreShown ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _craftBoosterIcon(gameCtrl.craftRewardType.value!),
                        color: _craftBoosterColor(
                          gameCtrl.craftRewardType.value!,
                        ),
                        size: 18,
                      ),
                      const SizedBox(width: NeonTheme.s8),
                      Text(
                        'craft_booster_reward_label'.trParams({
                          'booster': _craftBoosterLabel(
                            gameCtrl.craftRewardType.value!,
                          ),
                        }),
                        style: TextStyle(
                          color: _craftBoosterColor(
                            gameCtrl.craftRewardType.value!,
                          ),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                          label: 'retry'.tr.toUpperCase(),
                          color: NeonTheme.cyan,
                          onTap: widget.gsc.again,
                        ),
                      ),
                      const SizedBox(width: NeonTheme.s16),
                      Expanded(
                        child: NeonButton(
                          label: 'next_action'.tr.toUpperCase(),
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
  const _MascotDialog({
    required this.mood,
    required this.panel,
    required this.palette,
  });

  final StarMood mood;
  final Widget panel;
  final MascotPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarMascot(size: 104, mood: mood, palette: palette),
        Transform.translate(offset: const Offset(0, -16), child: panel),
      ],
    );
  }
}
