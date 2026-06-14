import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../core/app_info.dart';
import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../controllers/achievement_controller.dart';
import '../controllers/game_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/lucky_wheel_controller.dart';
import '../controllers/story_controller.dart';
import '../widgets/lucky_wheel_view.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_dialog.dart';
import 'achievements_screen.dart';
import 'game_screen.dart';
import 'guide_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'world_map_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final g = Get.put(GameController(), permanent: true);
    final hc = Get.put(HomeController(g));
    final ac = Get.put(AchievementController(g), permanent: true);
    final lw = Get.put(LuckyWheelController(g), permanent: true);
    Get.put(StoryController(), permanent: true);
    g.refillLives(); // cập nhật mạng hồi được khi quay về Home
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Stack(
            children: [
              _menu(g, ac),
              // Thanh trên: mạng (trái) + quà hằng ngày (phải)
              Positioned(
                top: NeonTheme.s8,
                left: NeonTheme.s16,
                child: Obx(() => GestureDetector(
                      onTap: g.lives.value < GameController.maxLives
                          ? hc.openLivesBuy
                          : null,
                      child: _LivesChip(g: g),
                    )),
              ),
              Positioned(
                top: NeonTheme.s8,
                right: NeonTheme.s16,
                child: Obx(() {
                  hc.lastReward.value; // refresh badge sau khi nhận
                  return _dailyButton(g, hc);
                }),
              ),
              // Vòng quay may mắn (trái nút quà)
              Positioned(
                top: NeonTheme.s8,
                right: 64,
                child: Obx(() {
                  lw.resultIndex.value; // refresh badge sau khi quay
                  return _wheelButton(lw);
                }),
              ),
              // Overlay daily (trong cây — route dialog no-op ở full-screen)
              Obx(() => hc.dailyOpen.value
                  ? _dailyOverlay(g, hc)
                  : const SizedBox.shrink()),
              // Overlay mua đầy mạng
              Obx(() => hc.livesBuyOpen.value
                  ? _livesBuyOverlay(g, hc)
                  : const SizedBox.shrink()),
              // Overlay vòng quay may mắn
              Obx(() => lw.open.value
                  ? _wheelOverlay(lw)
                  : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(GameController g, AchievementController ac) {
    return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s24, vertical: NeonTheme.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GemSparkle(),
                  const SizedBox(height: NeonTheme.s24),
                  Text(
                    'NEON',
                    style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 6,
                      shadows: NeonTheme.gemColors
                          .take(3)
                          .map((c) => Shadow(color: c, blurRadius: 24))
                          .toList(),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .shimmer(duration: 2200.ms, color: NeonTheme.cyan)
                      .scaleXY(begin: 1, end: 1.04, duration: 1600.ms),
                  const Text(
                    'JEWELS',
                    style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: NeonTheme.magenta,
                      letterSpacing: 10,
                      shadows: [Shadow(color: NeonTheme.magenta, blurRadius: 28)],
                    ),
                  ),
                  const SizedBox(height: NeonTheme.s24 * 1.6),
                  // NÚT CHÍNH — focus vào chơi ngay
                  NeonButton(
                    label: 'play_now'.tr,
                    color: NeonTheme.lime,
                    icon: Icons.play_arrow_rounded,
                    onTap: () {
                      // mở đúng kiểu xem người chơi đã chọn (lưu local; mặc định map)
                      final grid = StorageService.to
                              .getInt(StorageKeys.viewMode, def: 0) ==
                          1;
                      Get.to(() => grid
                          ? const LevelSelectScreen()
                          : const WorldMapScreen());
                    },
                  ),
                  const SizedBox(height: NeonTheme.s16),
                  // Chế độ Endless (thử thách tăng dần — không tốn mạng)
                  NeonButton(
                    label: 'endless_title'.tr,
                    color: NeonTheme.purple,
                    icon: Icons.all_inclusive_rounded,
                    onTap: () {
                      g.startEndless();
                      Get.to(() => const GameScreen());
                    },
                  ),
                  const SizedBox(height: NeonTheme.s24 * 1.2),
                  // PHỤ — hàng icon tròn gọn (thành tựu / hướng dẫn / cài đặt)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(() {
                        ac.claimed.length;
                        return _circleNav(
                          Icons.emoji_events_rounded,
                          NeonTheme.yellow,
                          'achievements'.tr,
                          () => Get.to(() => const AchievementsScreen()),
                          badge: ac.hasUnclaimed,
                        );
                      }),
                      const SizedBox(width: NeonTheme.s24),
                      _circleNav(Icons.menu_book_rounded, NeonTheme.magenta,
                          'guide'.tr, () => Get.to(() => const GuideScreen())),
                      const SizedBox(width: NeonTheme.s24),
                      _circleNav(
                          Icons.settings_rounded,
                          NeonTheme.purple,
                          'settings'.tr,
                          () => Get.to(() => const SettingsScreen())),
                    ],
                  ),
                  const SizedBox(height: NeonTheme.s24 * 1.4),
                  Text(
                    'v$kAppVersion',
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: NeonTheme.cyan, blurRadius: 12),
                        Shadow(color: NeonTheme.cyan, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: NeonTheme.s8),
                  Text(
                    kCopyright,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(color: NeonTheme.magenta, blurRadius: 12),
                        Shadow(color: NeonTheme.magenta, blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  /// Nút điều hướng phụ: icon tròn neon + nhãn nhỏ + badge tuỳ chọn.
  Widget _circleNav(IconData icon, Color color, String label, VoidCallback onTap,
      {bool badge = false}) {
    final circle = Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: NeonTheme.glow(color, blur: 10),
      ),
      child: Icon(icon, color: color, size: 26),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge
              ? Stack(clipBehavior: Clip.none, children: [
                  circle,
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: NeonTheme.lime,
                        shape: BoxShape.circle,
                        boxShadow: NeonTheme.glow(NeonTheme.lime, blur: 8),
                      ),
                    ),
                  ),
                ])
              : circle,
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Baloo2',
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              shadows: [Shadow(color: color, blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Lives chip
  // ------------------------------------------------------------ Daily button
  Widget _dailyButton(GameController g, HomeController hc) {
    final can = g.canClaimDaily;
    final btn = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(color: NeonTheme.yellow, width: 1.5),
        boxShadow: NeonTheme.glow(NeonTheme.yellow, blur: can ? 12 : 5),
      ),
      child: const Icon(Icons.card_giftcard_rounded,
          color: NeonTheme.yellow, size: 22),
    );
    return GestureDetector(
      onTap: hc.openDaily,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          can
              ? btn
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1, end: 1.12, duration: 700.ms)
              : btn,
          if (can)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: NeonTheme.lime,
                  shape: BoxShape.circle,
                  boxShadow: NeonTheme.glow(NeonTheme.lime, blur: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Wheel button
  Widget _wheelButton(LuckyWheelController lw) {
    final can = lw.canSpin;
    final btn = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(color: NeonTheme.lime, width: 1.5),
        boxShadow: NeonTheme.glow(NeonTheme.lime, blur: can ? 12 : 5),
      ),
      child: const Icon(Icons.casino_rounded, color: NeonTheme.lime, size: 22),
    );
    return GestureDetector(
      onTap: lw.openWheel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          can
              ? btn
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .rotate(begin: -0.03, end: 0.03, duration: 700.ms)
              : btn,
          if (can)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: NeonTheme.magenta,
                  shape: BoxShape.circle,
                  boxShadow: NeonTheme.glow(NeonTheme.magenta, blur: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- Wheel overlay
  Widget _wheelOverlay(LuckyWheelController lw) {
    return NeonDialog.overlay(
      onBarrier: lw.closeWheel,
      panel: NeonDialog.panel(
        title: 'wheel_title'.tr,
        color: NeonTheme.lime,
        icon: Icons.casino_rounded,
        content: LuckyWheelView(ctrl: lw),
        actions: [
          NeonDialogAction(
              label: 'btn_home'.tr,
              color: NeonTheme.cyan,
              onTap: lw.closeWheel),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- Daily overlay
  Widget _dailyOverlay(GameController g, HomeController hc) {
    final can = g.canClaimDaily;
    final got = hc.lastReward.value;
    final message = got > 0
        ? 'daily_got'.trParams({'n': '$got'})
        : (!can ? 'daily_claimed'.tr : null);
    return NeonDialog.overlay(
      onBarrier: hc.closeDaily,
      panel: NeonDialog.panel(
        title: 'daily_title'.tr,
        color: NeonTheme.yellow,
        icon: Icons.card_giftcard_rounded,
        message: message,
        content: _dailyGrid(g),
        actions: [
          if (can)
            NeonDialogAction(
                label: 'daily_claim'.tr,
                color: NeonTheme.lime,
                onTap: hc.claim)
          else
            NeonDialogAction(
                label: 'btn_home'.tr,
                color: NeonTheme.cyan,
                onTap: hc.closeDaily),
        ],
      ),
    );
  }

  // -------------------------------------------------------- Mua đầy mạng
  Widget _livesBuyOverlay(GameController g, HomeController hc) {
    return NeonDialog.overlay(
      onBarrier: hc.closeLivesBuy,
      panel: NeonDialog.panel(
        title: 'lives_buy_title'.tr,
        color: NeonTheme.magenta,
        icon: Icons.favorite_rounded,
        message: hc.buyFailed.value
            ? 'not_enough_coins'.tr
            : 'lives_buy_msg'.trParams({'n': '${HomeController.refillPrice}'}),
        actions: [
          NeonDialogAction(
              label: 'cancel'.tr,
              color: NeonTheme.cyan,
              onTap: hc.closeLivesBuy),
          NeonDialogAction(
              label: '${'buy'.tr} (${HomeController.refillPrice}💰)',
              color: NeonTheme.lime,
              onTap: hc.buyLives),
        ],
      ),
    );
  }

  Widget _dailyGrid(GameController g) {
    final streak = g.dailyStreak.value;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (i) {
        final day = i + 1;
        final reward = g.dailyRewardFor(day);
        // ngày đã nhận trong chu kỳ hiện tại (1..streak trong vòng 7)
        final claimedInCycle = ((streak - 1) % 7) + 1;
        final claimed = streak > 0 && day <= claimedInCycle;
        return Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: claimed
                ? NeonTheme.lime.withValues(alpha: 0.18)
                : NeonTheme.panel.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: claimed ? NeonTheme.lime : NeonTheme.yellow,
                width: claimed ? 2 : 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'daily_day'.trParams({'n': '$day'}),
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                claimed
                    ? Icons.check_circle_rounded
                    : Icons.monetization_on_rounded,
                color: claimed ? NeonTheme.lime : NeonTheme.yellow,
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                '$reward',
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Cụm gem nhỏ lấp lánh trên logo.
class _GemSparkle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        for (int i = 0; i < 5; i++)
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: NeonTheme.gemColors[i],
              borderRadius: BorderRadius.circular(8),
              boxShadow: NeonTheme.glow(NeonTheme.gemColors[i], blur: 14),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.8, end: 1.2, duration: (800 + i * 160).ms)
              .then()
              .rotate(begin: 0, end: 0.04),
      ],
    );
  }
}

class _LivesChip extends StatefulWidget {
  final GameController g;
  const _LivesChip({required this.g});

  @override
  State<_LivesChip> createState() => _LivesChipState();
}

class _LivesChipState extends State<_LivesChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (widget.g.lives.value < GameController.maxLives) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        widget.g.refillLives();
        if (!mounted) return;
        if (widget.g.lives.value >= GameController.maxLives) {
          _timer?.cancel();
          _timer = null;
        }
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lives = widget.g.lives.value;
      final full = lives >= GameController.maxLives;
      final next = widget.g.timeToNextLife;
      if (full && _timer != null) {
        _timer?.cancel();
        _timer = null;
      } else if (!full && _timer == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncTimer();
        });
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NeonTheme.magenta, width: 1.5),
          boxShadow: NeonTheme.glow(NeonTheme.magenta, blur: 6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.favorite_rounded,
              color: NeonTheme.magenta, size: 18),
          const SizedBox(width: 5),
          Text(
            '$lives',
            style: const TextStyle(
              fontFamily: 'Baloo2',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          if (!full && next > Duration.zero) ...[
            const SizedBox(width: 8),
            Icon(Icons.schedule_rounded,
                color: Colors.white.withValues(alpha: 0.7), size: 13),
            const SizedBox(width: 3),
            Text(
              HomeScreen._fmt(next),
              style: TextStyle(
                fontFamily: 'Baloo2',
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ]),
      );
    });
  }
}
