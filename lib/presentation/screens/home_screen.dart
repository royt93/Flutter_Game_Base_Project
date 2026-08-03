import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_info.dart';
import '../../core/haptics.dart';
import '../../core/neon_theme.dart';
import '../../core/runtime_flags.dart';
import '../../data/worlds.dart';
import '../controllers/game_controller.dart';
import '../controllers/home_screen_controller.dart';
import '../controllers/pass_and_play_controller.dart';
import '../controllers/treasure_map_controller.dart';
import '../widgets/ambient_particles.dart';
import '../widgets/board_frame_picker_dialog.dart';
import '../widgets/burst_style_picker_dialog.dart';
import '../widgets/coin_chip.dart';
import '../widgets/combo_text_style_picker_dialog.dart';
import '../widgets/home_carousel.dart';
import '../widgets/login_streak_dialog.dart';
import '../widgets/mystery_crate_dialog.dart';
import '../widgets/weekly_goal_dialog.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/neon_icon.dart';
import '../widgets/prestige_action.dart';
import '../widgets/pulse_glow.dart';
import '../widgets/spin_wheel_dialog.dart';
import '../widgets/star_mascot.dart';
import '../widgets/stroke_text.dart';
import 'achievements_screen.dart';
import 'boss_rush_screen.dart';
import 'color_alchemy_screen.dart';
import 'friend_compare_screen.dart';
import 'ghost_replay_screen.dart';
import 'game_screen.dart';
import 'guide_screen.dart';
import 'leaderboard_screen.dart';
import 'level_select_screen.dart';
import 'mascot_wardrobe_screen.dart';
import 'perks_screen.dart';
import 'pet_habitat_screen.dart';
import 'raid_boss_screen.dart';
import 'season_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'sky_shrine_screen.dart';
import 'star_road_screen.dart';
import 'stats_screen.dart';
import 'trophy_room_screen.dart';

/// Màn hình chính: logo, nút Play, banner ưu tiên đơn, 3 lối vào nhanh
/// (Shop/Daily Challenge/Modes), phần còn lại nằm trong endDrawer.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    final gameCtrl = Get.find<GameController>();
    Get.put(HomeScreenController()).refreshCards(gameCtrl);
    if (isE2eTest) return;

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
      title: 'home_comeback_title'.tr,
      color: NeonTheme.purple,
      icon: Icons.favorite_rounded,
      message: 'home_comeback_msg'.trParams({'coin': '$reward'}),
      actions: [
        NeonDialogAction(
          label: 'daily_claim'.tr,
          color: NeonTheme.purple,
          onTap: () {},
        ),
      ],
    );
  }

  void _showDailyRewardDialog(BuildContext context, GameController gameCtrl) {
    final nextStreak =
        (gameCtrl.dailyStreak.value % GameController.dailyRewards.length) + 1;
    final preview = GameController.dailyRewards[nextStreak - 1];
    NeonDialog.show(
      context: context,
      title: 'home_daily_title'.trParams({'day': '$nextStreak'}),
      color: NeonTheme.gold,
      icon: Icons.card_giftcard_rounded,
      message: 'home_daily_msg'.trParams({'coin': '$preview'}),
      actions: [
        NeonDialogAction(
          label: 'daily_claim'.tr,
          color: NeonTheme.gold,
          onTap: () {
            gameCtrl.claimDaily();
            Get.find<HomeScreenController>().refreshCards(gameCtrl);
          },
        ),
      ],
    );
  }

  void _showModesDialog(BuildContext context, GameController gameCtrl) {
    NeonDialog.show(
      context: context,
      title: 'modes_title'.tr,
      color: NeonTheme.indigo,
      icon: Icons.sports_esports_rounded,
      content: Wrap(
        alignment: WrapAlignment.center,
        spacing: NeonTheme.s8 / 2,
        runSpacing: NeonTheme.s16,
        children: [
          _modeTile(
            icon: Icons.timer_rounded,
            color: NeonTheme.orange,
            label: 'mode_time_attack_label'.tr,
            onTap: () {
              Navigator.pop(context);
              gameCtrl.startSideMode(GameMode.timeAttack);
              Get.to(() => const GameScreen());
            },
          ),
          _modeTile(
            icon: Icons.spa_rounded,
            color: NeonTheme.teal,
            label: 'mode_zen_label'.tr,
            onTap: () {
              Navigator.pop(context);
              gameCtrl.startSideMode(GameMode.zen);
              Get.to(() => const GameScreen());
            },
          ),
          _modeTile(
            icon: Icons.all_inclusive_rounded,
            color: NeonTheme.indigo,
            label: 'mode_endless_label'.tr,
            onTap: () {
              Navigator.pop(context);
              gameCtrl.startEndless();
              Get.to(() => const GameScreen());
            },
          ),
          _modeTile(
            icon: Icons.local_fire_department_rounded,
            color: NeonTheme.red,
            label: 'mode_boss_rush_label'.tr,
            onTap: () {
              Navigator.pop(context);
              Get.to(() => const BossRushScreen());
            },
          ),
          _modeTile(
            icon: Icons.flip_rounded,
            color: NeonTheme.cyan,
            label: 'mode_mirror_label'.tr,
            onTap: () {
              Navigator.pop(context);
              gameCtrl.startMirrorMode();
              Get.to(() => const GameScreen());
            },
          ),
          _modeTile(
            icon: gameCtrl.todaysGauntletModifier.icon,
            color: NeonTheme.gold,
            label: gameCtrl.todaysGauntletModifier.nameKey.tr,
            semanticLabel: 'mode_gauntlet_label'.tr,
            onTap: () {
              Navigator.pop(context);
              gameCtrl.startGauntlet();
              Get.to(() => const GameScreen());
            },
          ),
          _modeTile(
            icon: Icons.map_rounded,
            color: NeonTheme.teal,
            label: 'treasure_map_title'.tr,
            onTap: () {
              if (gameCtrl.treasureMapCount.value <= 0) {
                Navigator.pop(context);
                NeonDialog.show(
                  context: context,
                  title: 'treasure_map_title'.tr,
                  color: NeonTheme.teal,
                  message: 'treasure_no_maps'.tr,
                  actions: [
                    NeonDialogAction(
                      label: 'coll_close'.tr,
                      color: NeonTheme.teal,
                      onTap: () {},
                    ),
                  ],
                );
                return;
              }
              Navigator.pop(context);
              final expedition = Get.put(TreasureMapController(gameCtrl));
              if (expedition.startExpedition()) {
                Get.to(() => const GameScreen());
              }
            },
          ),
          _modeTile(
            icon: Icons.people_rounded,
            color: NeonTheme.purple,
            label: 'duel_title'.tr,
            onTap: () {
              Navigator.pop(context);
              final duel = Get.put(PassAndPlayController(gameCtrl));
              duel.startDuel();
              Get.to(() => const GameScreen());
            },
          ),
          _modeTile(
            icon: Icons.event_rounded,
            color: NeonTheme.magenta,
            label: worldForLevel(gameCtrl.featuredLevelId).nameKey.tr,
            semanticLabel: 'mode_weekly_featured_label'.tr,
            onTap: () {
              Navigator.pop(context);
              gameCtrl.startWeeklyFeatured();
              Get.to(() => const GameScreen());
            },
          ),
        ],
      ),
      actions: [
        NeonDialogAction(
          label: 'cancel'.tr,
          color: NeonTheme.indigo,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _modeTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeonIconButton(
          icon,
          color: color,
          size: 28,
          boxed: true,
          semanticLabel: semanticLabel ?? label,
          onTap: onTap,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: NeonIcon(icon, color: color, size: 24),
      title: Text(
        label,
        style: TextStyle(color: NeonTheme.ink, fontWeight: FontWeight.w700),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildDrawer(BuildContext context, GameController gameCtrl) {
    return Drawer(
      backgroundColor: NeonTheme.card,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(NeonTheme.s16),
              child: StrokeText(
                kAppName,
                fontSize: 22,
                color: NeonTheme.ink,
                stroke: NeonTheme.magenta,
                strokeWidth: 3,
              ),
            ),
            Divider(color: NeonTheme.inkSoft, height: 1),
            _drawerTile(
              icon: Icons.auto_awesome_rounded,
              color: NeonTheme.gold,
              label: 'star_road_title'.tr,
              onTap: () => Get.to(() => const StarRoadScreen()),
            ),
            _drawerTile(
              icon: Icons.casino_rounded,
              color: NeonTheme.purple,
              label: 'spin_wheel_label'.tr,
              onTap: () => showSpinWheelDialog(context, gameCtrl),
            ),
            _drawerTile(
              icon: Icons.menu_book_rounded,
              color: NeonTheme.lime,
              label: 'guide'.tr,
              onTap: () => Get.to(() => const GuideScreen()),
            ),
            Divider(color: NeonTheme.inkSoft, height: 1),
            _drawerTile(
              icon: Icons.settings_rounded,
              color: NeonTheme.blue,
              label: 'settings'.tr,
              onTap: () => Get.to(() => const SettingsScreen()),
            ),
            _drawerTile(
              icon: Icons.leaderboard_rounded,
              color: NeonTheme.cyan,
              label: 'leaderboard_title'.tr,
              onTap: () => Get.to(() => const LeaderboardScreen()),
            ),
            _drawerTile(
              icon: Icons.people_alt_rounded,
              color: NeonTheme.teal,
              label: 'friend_compare_title'.tr,
              onTap: () => Get.to(() => const FriendCompareScreen()),
            ),
            _drawerTile(
              icon: Icons.movie_creation_rounded,
              color: NeonTheme.magenta,
              label: 'ghost_replay_title'.tr,
              onTap: () => Get.to(() => const GhostReplayScreen()),
            ),
            _drawerTile(
              icon: Icons.military_tech_rounded,
              color: NeonTheme.magenta,
              label: 'season_pass_title'.tr,
              onTap: () => Get.to(() => const SeasonScreen()),
            ),
            _drawerTile(
              icon: Icons.auto_fix_high_rounded,
              color: NeonTheme.pink,
              label: 'perks_title'.tr,
              onTap: () => Get.to(() => const PerksScreen()),
            ),
            _drawerTile(
              icon: Icons.emoji_events_rounded,
              color: NeonTheme.gold,
              label: 'achievements_title'.tr,
              onTap: () => Get.to(() => const AchievementsScreen()),
            ),
            _drawerTile(
              icon: Icons.checkroom_rounded,
              color: NeonTheme.magenta,
              label: 'wardrobe_title'.tr,
              onTap: () => Get.to(() => const MascotWardrobeScreen()),
            ),
            _drawerTile(
              icon: Icons.palette_rounded,
              color: NeonTheme.purple,
              label: 'alchemy_title'.tr,
              onTap: () => Get.to(() => const ColorAlchemyScreen()),
            ),
            _drawerTile(
              icon: Icons.military_tech_rounded,
              color: NeonTheme.gold,
              label: 'trophy_room_title'.tr,
              onTap: () => Get.to(() => const TrophyRoomScreen()),
            ),
            _drawerTile(
              icon: Icons.auto_awesome_rounded,
              color: NeonTheme.teal,
              label: 'pet_habitat_title'.tr,
              onTap: () => Get.to(() => const PetHabitatScreen()),
            ),
            _drawerTile(
              icon: Icons.auto_awesome_motion_rounded,
              color: NeonTheme.indigo,
              label: 'drawer_burst_style_label'.tr,
              onTap: () => showBurstStylePickerDialog(context, gameCtrl),
            ),
            _drawerTile(
              icon: Icons.text_fields_rounded,
              color: NeonTheme.yellow,
              label: 'drawer_combo_text_style_label'.tr,
              onTap: () => showComboTextStylePickerDialog(context, gameCtrl),
            ),
            _drawerTile(
              icon: Icons.event_available_rounded,
              color: NeonTheme.red,
              label: 'drawer_login_streak_label'.tr,
              onTap: () => showLoginStreakDialog(context, gameCtrl),
            ),
            _drawerTile(
              icon: Icons.bar_chart_rounded,
              color: NeonTheme.orange,
              label: 'drawer_stats_label'.tr,
              onTap: () => Get.to(() => const StatsScreen()),
            ),
            _drawerTile(
              icon: Icons.flag_rounded,
              color: NeonTheme.teal,
              label: 'drawer_weekly_goal_label'.tr,
              onTap: () => showWeeklyGoalDialog(context, gameCtrl),
            ),
            _drawerTile(
              icon: Icons.crop_free_rounded,
              color: NeonTheme.indigo,
              label: 'drawer_board_frame_label'.tr,
              onTap: () => showBoardFramePickerDialog(context, gameCtrl),
            ),
            _drawerTile(
              icon: Icons.auto_awesome_rounded,
              color: NeonTheme.cyan,
              label: 'sky_shrine_title'.tr,
              onTap: () => Get.to(() => const SkyShrineScreen()),
            ),
            _drawerTile(
              icon: Icons.inventory_2_rounded,
              color: NeonTheme.magenta,
              label: 'mystery_crate_title'.tr,
              onTap: () => showMysteryCrateDialog(context, gameCtrl),
            ),
            _drawerTile(
              icon: Icons.whatshot_rounded,
              color: NeonTheme.red,
              label: 'raid_boss_title'.tr,
              onTap: () => Get.to(() => const RaidBossScreen()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildDrawer(context, gameCtrl),
      // I53: nền home tự đổi màu/thời tiết theo world cao nhất đã unlock —
      // TweenAnimationBuilder tự tạo tween mới từ màu animated hiện tại sang
      // màu world mới mỗi khi Obx rebuild với world khác, tránh snap đột ngột.
      body: Obx(() {
        final world = worldForLevel(gameCtrl.unlockedLevel.value);
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: world.color, end: world.color),
          duration: const Duration(milliseconds: 800),
          builder: (context, animatedColor, child) => NeonBg(
            accent: animatedColor,
            weather: world.weather,
            child: child!,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NeonTheme.s16,
                    vertical: NeonTheme.s8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      NeonIconButton(
                        Icons.menu_rounded,
                        color: NeonTheme.cyan,
                        onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                        semanticLabel: 'menu_button_label'.tr,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PrestigeAction(
                            gameCtrl: gameCtrl,
                            onTap: () => showPrestigeDialog(context, gameCtrl),
                          ),
                          CoinChip(gameCtrl),
                        ],
                      ),
                    ],
                  ),
                ),
                Obx(() {
                  final homeCtrl = Get.find<HomeScreenController>();
                  return HomeCarousel(
                    cards: homeCtrl.cards,
                    currentIndex: homeCtrl.currentIndex.value,
                    onPageChanged: (i) => homeCtrl.currentIndex.value = i,
                    onCardTapped: () => homeCtrl.refreshCards(gameCtrl),
                  );
                }),
                const Spacer(flex: 2),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 220,
                      height: 220,
                      child: AmbientParticles(),
                    ),
                    Obx(
                      () => StarMascot(
                        size: 128,
                        onTap: () => fireHaptic(HapticLevel.light),
                        palette: gameCtrl.activeMascotSkin.palette,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NeonTheme.s8),
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
                Obx(() {
                  final name = gameCtrl.playerName.value;
                  if (name.isEmpty) return const SizedBox.shrink();
                  final title = gameCtrl.activeTitleAchievement;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      title == null ? name : '$name · ${title.titleKey.tr}',
                      style: TextStyle(
                        color: NeonTheme.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
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
                const SizedBox(height: NeonTheme.s24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NeonIconButton(
                      Icons.storefront_rounded,
                      color: NeonTheme.yellow,
                      size: 28,
                      boxed: true,
                      semanticLabel: 'shop_title'.tr,
                      onTap: () => Get.to(() => const ShopScreen()),
                    ),
                    const SizedBox(width: NeonTheme.s24),
                    NeonIconButton(
                      Icons.calendar_month_rounded,
                      color: NeonTheme.red,
                      size: 28,
                      boxed: true,
                      semanticLabel: 'daily_challenge_label'.tr,
                      onTap: () {
                        gameCtrl.startDailyChallenge();
                        Get.to(() => const GameScreen());
                      },
                    ),
                    const SizedBox(width: NeonTheme.s24),
                    NeonIconButton(
                      Icons.sports_esports_rounded,
                      color: NeonTheme.indigo,
                      size: 28,
                      boxed: true,
                      semanticLabel: 'modes_title'.tr,
                      onTap: () => _showModesDialog(context, gameCtrl),
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: NeonTheme.s16),
                  child: Column(
                    children: [
                      Text(
                        kCopyright,
                        style: TextStyle(
                          color: NeonTheme.ink.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'v$kAppVersion+$kAppBuildNumber',
                        style: TextStyle(
                          color: NeonTheme.ink.withValues(alpha: 0.35),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
