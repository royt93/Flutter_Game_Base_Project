import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_info.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/weekend_event.dart';
import '../controllers/game_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/neon_icon.dart';
import '../widgets/pulse_glow.dart';
import '../widgets/spin_wheel_dialog.dart';
import '../widgets/star_mascot.dart';
import '../widgets/stroke_text.dart';
import 'game_screen.dart';
import 'guide_screen.dart';
import 'leaderboard_screen.dart';
import 'level_select_screen.dart';
import 'perks_screen.dart';
import 'season_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'star_road_screen.dart';

/// Màn hình chính: logo, nút Play, và lối vào Shop/Guide/Settings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final gameCtrl = Get.find<GameController>();
    final comebackReward = gameCtrl.checkComebackBonus();
    if (comebackReward != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showComebackDialog(context, comebackReward),
      );
    } else if (gameCtrl.canClaimDaily) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showDailyRewardDialog(context, gameCtrl),
      );
    }
  }

  void _showComebackDialog(BuildContext context, int reward) {
    NeonDialog.show(
      context: context,
      title: 'Chào mừng trở lại!',
      color: NeonTheme.purple,
      icon: Icons.favorite_rounded,
      message: 'Quà comeback: +$reward xu, +1 bomb, +1 shuffle!',
      actions: [
        NeonDialogAction(label: 'Nhận', color: NeonTheme.purple, onTap: () {}),
      ],
    );
  }

  void _showDailyRewardDialog(BuildContext context, GameController gameCtrl) {
    final nextStreak =
        (gameCtrl.dailyStreak.value % GameController.dailyRewards.length) + 1;
    final preview = GameController.dailyRewards[nextStreak - 1];
    NeonDialog.show(
      context: context,
      title: 'Daily reward — Day $nextStreak',
      color: NeonTheme.gold,
      icon: Icons.card_giftcard_rounded,
      message: 'Nhận $preview xu hôm nay!',
      actions: [
        NeonDialogAction(
          label: 'Nhận',
          color: NeonTheme.gold,
          onTap: gameCtrl.claimDaily,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  child: CoinChip(gameCtrl),
                ),
              ),
              if (isWeekendEvent(DateTime.now()))
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: NeonTheme.s16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: NeonTheme.s16,
                    vertical: NeonTheme.s8,
                  ),
                  decoration: BoxDecoration(
                    color: NeonTheme.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Cuối tuần x2 coin!',
                    style: TextStyle(
                      color: NeonTheme.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              const Spacer(flex: 2),
              const StarMascot(size: 128),
              const SizedBox(height: NeonTheme.s16),
              StrokeText(
                kAppName,
                fontSize: 46,
                color: Colors.white,
                stroke: NeonTheme.magenta,
                strokeWidth: 6,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: NeonTheme.purple.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              const Spacer(flex: 3),
              PulseGlow(
                color: NeonTheme.cyan,
                child: NeonButton(
                  label: 'PLAY',
                  color: NeonTheme.cyan,
                  icon: Icons.play_arrow_rounded,
                  onTap: () => Get.to(() => const LevelSelectScreen()),
                ),
              ),
              const SizedBox(height: NeonTheme.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NeonIconButton(
                    Icons.timer_rounded,
                    color: NeonTheme.orange,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Chế độ Đấu thời gian',
                    onTap: () {
                      gameCtrl.startSideMode(GameMode.timeAttack);
                      Get.to(() => const GameScreen());
                    },
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.spa_rounded,
                    color: NeonTheme.teal,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Chế độ Thư giãn',
                    onTap: () {
                      gameCtrl.startSideMode(GameMode.zen);
                      Get.to(() => const GameScreen());
                    },
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.all_inclusive_rounded,
                    color: NeonTheme.indigo,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Chế độ Vô tận',
                    onTap: () {
                      gameCtrl.startEndless();
                      Get.to(() => const GameScreen());
                    },
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.calendar_month_rounded,
                    color: NeonTheme.red,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Daily Challenge',
                    onTap: () {
                      gameCtrl.startDailyChallenge();
                      Get.to(() => const GameScreen());
                    },
                  ),
                ],
              ),
              const SizedBox(height: NeonTheme.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NeonIconButton(
                    Icons.auto_awesome_rounded,
                    color: NeonTheme.gold,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Con đường sao',
                    onTap: () => Get.to(() => const StarRoadScreen()),
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.casino_rounded,
                    color: NeonTheme.purple,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Vòng quay may mắn',
                    onTap: () => showSpinWheelDialog(context, gameCtrl),
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.storefront_rounded,
                    color: NeonTheme.yellow,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Cửa hàng',
                    onTap: () => Get.to(() => const ShopScreen()),
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.menu_book_rounded,
                    color: NeonTheme.lime,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Hướng dẫn',
                    onTap: () => Get.to(() => const GuideScreen()),
                  ),
                ],
              ),
              const SizedBox(height: NeonTheme.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NeonIconButton(
                    Icons.settings_rounded,
                    color: NeonTheme.blue,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Cài đặt',
                    onTap: () => Get.to(() => const SettingsScreen()),
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.leaderboard_rounded,
                    color: NeonTheme.cyan,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Leaderboard',
                    onTap: () => Get.to(() => const LeaderboardScreen()),
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.military_tech_rounded,
                    color: NeonTheme.magenta,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Season Pass',
                    onTap: () => Get.to(() => const SeasonScreen()),
                  ),
                  const SizedBox(width: NeonTheme.s24),
                  NeonIconButton(
                    Icons.auto_fix_high_rounded,
                    color: NeonTheme.pink,
                    size: 28,
                    boxed: true,
                    semanticLabel: 'Perks',
                    onTap: () => Get.to(() => const PerksScreen()),
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: NeonTheme.s16),
                child: Text(
                  kCopyright,
                  style: TextStyle(
                    color: NeonTheme.ink.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
