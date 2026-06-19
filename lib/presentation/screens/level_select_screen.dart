import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../data/levels.dart';
import '../../data/story.dart';
import '../controllers/game_controller.dart';
import '../controllers/pregame_controller.dart';
import '../controllers/story_controller.dart';
import '../../core/utils/format.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/story_overlay.dart';
import 'game_screen.dart';
import 'world_map_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  Color _colorOf(int index) =>
      NeonTheme.gemColors[(index - 1) % NeonTheme.gemColors.length];

  IconData _objIcon(ObjectiveType o) {
    switch (o) {
      case ObjectiveType.score:
        return Icons.star_rounded;
      case ObjectiveType.collect:
        return Icons.diamond_rounded;
      case ObjectiveType.clearJelly:
        return Icons.blur_on_rounded;
      case ObjectiveType.timeAttack:
        return Icons.timer_rounded;
      case ObjectiveType.dropDown:
        return Icons.south_rounded;
      case ObjectiveType.clearObstacle:
        return Icons.ac_unit_rounded;
      case ObjectiveType.order:
        return Icons.checklist_rounded;
      case ObjectiveType.endless:
        return Icons.all_inclusive_rounded;
      case ObjectiveType.boss:
        return Icons.coronavirus_rounded;
      case ObjectiveType.soda:
        return Icons.local_drink_rounded;
    }
  }

  void _play(GameController ctrl, int index) {
    // hết mạng → chặn vào màn + báo thời gian hồi
    if (!ctrl.hasLife) {
      final ctx = Get.context;
      if (ctx != null) {
        final next = ctrl.timeToNextLife;
        final msg = next > Duration.zero
            ? '${'lives_none_msg'.tr} (${fmtDur(next)})'
            : 'lives_none_msg'.tr;
        ScaffoldMessenger.of(ctx)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(msg,
                style: const TextStyle(fontFamily: 'Baloo2', fontSize: 13)),
            backgroundColor: NeonTheme.panel,
            behavior: SnackBarBehavior.floating,
          ));
      }
      return;
    }
    // cốt truyện intro/mid trước khi vào màn (chỉ lần đầu mỗi beat)
    final t = storyStartTriggerFor(index);
    if (t != null &&
        StoryController.to.maybeShow(t, worldOfLevel(index).index,
            onComplete: () => _afterStory(ctrl, index))) {
      return;
    }
    _afterStory(ctrl, index);
  }

  void _afterStory(GameController ctrl, int index) {
    // có booster để chọn → mở pre-game panel; nếu không, vào thẳng
    final pg = Get.find<PregameController>();
    if (pg.hasAny) {
      pg.openFor(index);
    } else {
      _enter(ctrl, index);
    }
  }

  void _enter(GameController ctrl, int index) {
    ctrl.startLevel(index);
    Get.to(() => const GameScreen());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<GameController>();
    final pg = Get.put(PregameController(ctrl));
    return Scaffold(
      body: NeonBg(
        child: Stack(
          children: [
          SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'select_level'.tr,
                color: NeonTheme.cyan,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.map_rounded, color: NeonTheme.cyan),
                    tooltip: 'world_map'.tr,
                    onPressed: () {
                      // chủ động đổi style → lưu local (world map)
                      StorageService.to.setInt(StorageKeys.viewMode, 0);
                      Get.off(() => const WorldMapScreen());
                    },
                  ),
                  CoinChip(ctrl),
                ],
              ),
              Expanded(
                child: Obx(() {
                  final current =
                      ctrl.unlockedLevel.value.clamp(1, kLevels.length);
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(NeonTheme.s24,
                              NeonTheme.s8, NeonTheme.s24, NeonTheme.s16),
                          child: _featured(ctrl, current),
                        ),
                      ),
                      // gom màn theo từng thế giới (20 màn / thế giới)
                      for (final w in kWorlds) ...[
                        SliverToBoxAdapter(child: _worldHeader(ctrl, w, current)),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(NeonTheme.s24, 0,
                              NeonTheme.s24, NeonTheme.s16),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: NeonTheme.s8,
                              crossAxisSpacing: NeonTheme.s8,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final lv = kLevels[w.startLevel - 1 + i];
                                return _miniTile(ctrl, lv, lv.index <= current,
                                    lv.index == current);
                              },
                              childCount: w.endLevel - w.startLevel + 1,
                            ),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(
                          child: SizedBox(height: NeonTheme.s16)),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
        Obx(() => pg.open.value
            ? _pregameOverlay(ctrl, pg)
            : const SizedBox.shrink()),
          const StoryOverlay(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------- Pre-game overlay
  Widget _pregameOverlay(GameController ctrl, PregameController pg) {
    return NeonDialog.overlay(
      onBarrier: pg.close,
      panel: NeonDialog.panel(
        title: 'pregame_title'.tr,
        color: NeonTheme.lime,
        icon: Icons.rocket_launch_rounded,
        message: 'pregame_msg'.tr,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => _pregameOption(
                  icon: Icons.av_timer_rounded,
                  color: NeonTheme.lime,
                  label: 'pregame_moves'.tr,
                  count: ctrl.boosterMoves.value,
                  selected: pg.useMoves.value,
                  onTap: pg.toggleMoves,
                )),
            const SizedBox(height: NeonTheme.s8),
            Obx(() => _pregameOption(
                  icon: Icons.gavel_rounded,
                  color: NeonTheme.orange,
                  label: 'pregame_hammer'.tr,
                  count: ctrl.boosterHammer.value,
                  selected: pg.armHammer.value,
                  onTap: pg.toggleHammer,
                )),
          ],
        ),
        actions: [
          NeonDialogAction(
              label: 'pregame_skip'.tr,
              color: NeonTheme.cyan,
              onTap: () {
                pg.useMoves.value = false;
                pg.armHammer.value = false;
                pg.start();
                _enter(ctrl, pg.level.value);
              }),
          NeonDialogAction(
              label: 'play_now'.tr,
              color: NeonTheme.lime,
              onTap: () {
                pg.start();
                _enter(ctrl, pg.level.value);
              }),
        ],
      ),
    );
  }

  Widget _pregameOption({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final owned = count > 0;
    return GestureDetector(
      onTap: owned ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.25)
              : NeonTheme.panel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: owned ? color : Colors.white24,
              width: selected ? 2.5 : 1.4),
          boxShadow: selected ? NeonTheme.glow(color, blur: 10) : null,
        ),
        child: Row(children: [
          Icon(icon, color: owned ? color : Colors.white38, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  color: owned ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
          ),
          Text('x$count',
              style: TextStyle(
                color: owned ? color : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(width: 6),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            color: selected ? color : Colors.white30,
            size: 18,
          ),
        ]),
      ),
    );
  }

  Color _worldColor(int worldIndex) => NeonTheme.accentForWorld(worldIndex);

  /// Banner tiêu đề thế giới: số + tên chủ đề + tiến trình (sao + màn xong).
  Widget _worldHeader(GameController ctrl, WorldConfig w, int current) {
    final c = _worldColor(w.index);
    final reached = current >= w.startLevel; // đã tới thế giới này chưa
    var stars = 0;
    var done = 0;
    for (int lv = w.startLevel; lv <= w.endLevel; lv++) {
      stars += ctrl.stars[lv] ?? 0;
      if (lv < current) done++;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          NeonTheme.s24, NeonTheme.s8, NeonTheme.s24, NeonTheme.s8),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: NeonTheme.s16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            c.withValues(alpha: reached ? 0.3 : 0.12),
            NeonTheme.panel.withValues(alpha: 0.8),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: reached ? c : c.withValues(alpha: 0.4), width: 2),
          boxShadow: reached ? NeonTheme.glow(c, blur: 10) : null,
        ),
        child: Row(
          children: [
            Icon(reached ? Icons.public_rounded : Icons.lock_rounded,
                color: reached ? c : Colors.white38, size: 24),
            const SizedBox(width: NeonTheme.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'world_n'.trParams({'n': '${w.index}'}),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      shadows: [Shadow(color: c, blurRadius: 10)],
                    ),
                  ),
                  Text(
                    worldNameKey(w.index).tr,
                    style: TextStyle(
                      color: c,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            // tiến trình: sao + số màn xong
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 3),
              Text('$stars',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(width: NeonTheme.s8),
              Text('$done/${w.endLevel - w.startLevel + 1}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _featured(GameController ctrl, int index) {
    final lv = kLevels[index - 1];
    final c = _colorOf(index);
    final hs = ctrl.highScores[index];
    return GestureDetector(
      onTap: () => _play(ctrl, index),
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            c.withValues(alpha: 0.25),
            NeonTheme.panel.withValues(alpha: 0.85),
          ]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c, width: 2.5),
          boxShadow: NeonTheme.glow(c, blur: 18),
        ),
        child: Row(
          children: [
            _emblem(index, c, 84),
            const SizedBox(width: NeonTheme.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('stage_n'.trParams({'n': '$index'}),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: c, blurRadius: 12)],
                      )),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(_objIcon(lv.objective), color: c, size: 16),
                    const SizedBox(width: 6),
                    Text(hs != null ? '★ $hs' : '★ —',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: NeonTheme.glow(c, blur: 10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 4),
                      Text('play_now'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          )),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (a) => a.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.015, duration: 1200.ms, curve: Curves.easeInOut);
  }

  /// Wave 16 — badge tier độ khó ở góc tile (Hard cam / Super-Hard đỏ; Normal
  /// không hiện để đỡ rối). Chỉ hiện khi đã mở khoá.
  Widget? _tierCorner(int index) {
    final t = levelTier(index);
    if (t == LevelTier.superHard) {
      return _cornerChip(Icons.whatshot_rounded, const Color(0xFFFF3B5C));
    }
    if (t == LevelTier.hard) {
      return _cornerChip(Icons.bolt_rounded, NeonTheme.orange);
    }
    return null;
  }

  Widget _cornerChip(IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xCC0B0B1F),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.2),
          boxShadow: NeonTheme.glow(color, blur: 4),
        ),
        child: Icon(icon, color: color, size: 11),
      );

  Widget _miniTile(
      GameController ctrl, LevelConfig lv, bool unlocked, bool isCurrent) {
    final c = unlocked ? _colorOf(lv.index) : Colors.grey.shade700;
    final star = ctrl.stars[lv.index] ?? 0;
    final corner = unlocked ? _tierCorner(lv.index) : null;
    final tile = GestureDetector(
      onTap: unlocked ? () => _play(ctrl, lv.index) : null,
      child: Container(
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isCurrent ? Colors.white : c,
              width: isCurrent ? 2.5 : 1.6),
          boxShadow: unlocked ? NeonTheme.glow(c, blur: 7) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unlocked)
              Text('${lv.index}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: c, blurRadius: 8)],
                  ))
            else
              const Icon(Icons.lock_rounded, color: Colors.white38, size: 18),
            if (unlocked) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (s) => Icon(
                    Icons.star_rounded,
                    size: 9,
                    color: s < star ? Colors.amber : Colors.white24,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (corner == null) return tile;
    return Stack(
      clipBehavior: Clip.none,
      children: [tile, Positioned(top: -4, right: -4, child: corner)],
    );
  }

  Widget _emblem(int index, Color c, double size) {
    final light = Color.lerp(c, Colors.white, 0.5)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [light, c, Color.lerp(c, Colors.black, 0.3)!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
        boxShadow: NeonTheme.glow(c, blur: 12),
      ),
      alignment: Alignment.center,
      child: Text('$index',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
          )),
    );
  }
}
