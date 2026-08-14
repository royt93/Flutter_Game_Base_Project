import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/haptics.dart';
import '../../core/neon_theme.dart';
import '../../core/runtime_flags.dart';
import '../../core/share_helper.dart';
import '../../data/worlds.dart';
import '../../logic/next_action.dart';
import '../controllers/game_controller.dart';
import '../controllers/home_screen_controller.dart';
import '../widgets/ambient_particles.dart';
import '../widgets/burst_style_picker_dialog.dart';
import '../widgets/coin_chip.dart';
import '../widgets/clan_dialog.dart';
import '../widgets/combo_text_style_picker_dialog.dart';
import '../widgets/daily_quest_dialog.dart';
import '../widgets/home_carousel.dart';
import '../widgets/login_streak_dialog.dart';
import '../widgets/mystery_crate_dialog.dart';
import '../widgets/next_up_bar.dart';
import '../widgets/weekly_goal_dialog.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_dialog.dart';
import '../widgets/neon_icon.dart';
import '../widgets/prestige_action.dart';
import '../widgets/pulse_glow.dart';
import '../widgets/spin_wheel_dialog.dart';
import '../widgets/star_mascot.dart';
import '../widgets/token_chip.dart';
import '../widgets/stroke_text.dart';
import 'achievements_screen.dart';
import 'board_frame_screen.dart';
import 'color_alchemy_screen.dart';
import 'friend_compare_screen.dart';
import 'ghost_replay_screen.dart';
import 'game_screen.dart';
import 'guide_screen.dart';
import 'leaderboard_screen.dart';
import 'level_select_screen.dart';
import 'mascot_wardrobe_screen.dart';
import 'milestone_journal_screen.dart';
import 'mode_select_screen.dart';
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
  final _shopButtonLink = LayerLink();
  final _dailyButtonLink = LayerLink();

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
      message: _comebackMessage(reward),
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
          key: const PageStorageKey('home_drawer_list'),
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
              icon: Icons.auto_stories_rounded,
              color: NeonTheme.purple,
              label: 'drawer_milestone_journal_label'.tr,
              onTap: () => Get.to(() => const MilestoneJournalScreen()),
            ),
            _drawerTile(
              icon: Icons.task_alt_rounded,
              color: NeonTheme.purple,
              label: 'daily_quest_title'.tr,
              onTap: () => showDailyQuestDialog(context, gameCtrl),
            ),
            _drawerTile(
              icon: Icons.flag_rounded,
              color: NeonTheme.teal,
              label: 'drawer_weekly_goal_label'.tr,
              onTap: () => showWeeklyGoalDialog(context, gameCtrl),
            ),
            _drawerTile(
              icon: Icons.groups_rounded,
              color: NeonTheme.purple,
              label: 'clan_title'.tr,
              onTap: () => showClanDialog(context, gameCtrl),
            ),
            _drawerTile(
              icon: Icons.crop_free_rounded,
              color: NeonTheme.indigo,
              label: 'drawer_board_frame_label'.tr,
              onTap: () => Get.to(() => const BoardFrameScreen()),
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
            child: Stack(
              children: [
                // I84: Home vốn là Column cố định với Spacer, và ở chiều cao
                // ~600dp nó đã vừa khít — thêm BẤT KỲ nội dung nào cũng tràn
                // (dải "Tiếp theo" làm lộ ra điều này, nhưng hạn chế có sẵn từ
                // trước). Bọc scroll + ép cao tối thiểu bằng viewport: máy cao
                // vẫn dàn đều nhờ Spacer như cũ, máy thấp thì cuộn được thay
                // vì vẽ tràn.
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: NeonTheme.s16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  NeonIconButton(
                                    Icons.menu_rounded,
                                    color: NeonTheme.cyan,
                                    onTap: () => _scaffoldKey.currentState
                                        ?.openEndDrawer(),
                                    semanticLabel: 'menu_button_label'.tr,
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PrestigeAction(
                                        gameCtrl: gameCtrl,
                                        onTap: () => showPrestigeDialog(
                                          context,
                                          gameCtrl,
                                        ),
                                      ),
                                      CoinChip(gameCtrl),
                                      // F17: số dư Combo Token đứng cạnh xu —
                                      // hai tiền tệ, một chỗ nhìn.
                                      TokenChip(gameCtrl),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // I84: dải "Tiếp theo" nằm TRÊN carousel — carousel đầy đủ
                            // vẫn ở dưới cho ai muốn khám phá, không thay thế nó.
                            Obx(() {
                              // Đọc vài Rx để Obx dựng lại khi state đổi (nhận thưởng,
                              // thắng màn...) — `nextActions()` là hàm thường, không tự
                              // đăng ký phụ thuộc.
                              gameCtrl.coins.value;
                              gameCtrl.unlockedLevel.value;
                              gameCtrl.totalStars.value;
                              gameCtrl.weeklyGoalProgress.value;
                              gameCtrl.dailyQuestProgress.length;
                              return NextUpBar(
                                actions: gameCtrl.nextActions(),
                                onTap: (a) =>
                                    _onNextAction(context, gameCtrl, a),
                              );
                            }),
                            const SizedBox(height: NeonTheme.s8),
                            Obx(() {
                              final homeCtrl = Get.find<HomeScreenController>();
                              return HomeCarousel(
                                cards: homeCtrl.cards.toList(),
                                currentIndex: homeCtrl.currentIndex.value,
                                onPageChanged: (i) =>
                                    homeCtrl.currentIndex.value = i,
                                onCardTapped: () =>
                                    homeCtrl.refreshCards(gameCtrl),
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
                            StrokeText(
                              kAppName,
                              fontSize: 46,
                              color: Colors.white,
                              stroke: NeonTheme.magenta,
                              strokeWidth: 6,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: NeonTheme.purple.withValues(
                                    alpha: 0.5,
                                  ),
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
                                  title == null
                                      ? name
                                      : '$name · ${title.titleKey.tr}',
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
                                // Nút to nhất màn hình mà trước đây hardcode
                                // 'PLAY' — không đi qua i18n nên đứng nguyên
                                // tiếng Anh ở cả 21 ngôn ngữ. `play_now` đã
                                // có sẵn bản dịch cho đủ 22 locale.
                                label: 'play_now'.tr.toUpperCase(),
                                color: NeonTheme.cyan,
                                icon: Icons.play_arrow_rounded,
                                onTap: () =>
                                    Get.to(() => const LevelSelectScreen()),
                              ),
                            ),
                            const SizedBox(height: NeonTheme.s8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Obx(() {
                                  final homeCtrl =
                                      Get.find<HomeScreenController>();
                                  final shopButton = NeonIconButton(
                                    Icons.storefront_rounded,
                                    color: NeonTheme.yellow,
                                    size: 28,
                                    boxed: true,
                                    semanticLabel: 'shop_title'.tr,
                                    onTap: () {
                                      homeCtrl.dismissShopTutorial();
                                      Get.to(() => const ShopScreen());
                                    },
                                  );
                                  return CompositedTransformTarget(
                                    link: _shopButtonLink,
                                    child: homeCtrl.showShopTutorial.value
                                        ? PulseGlow(
                                            color: NeonTheme.yellow,
                                            child: shopButton,
                                          )
                                        : shopButton,
                                  );
                                }),
                                const SizedBox(width: NeonTheme.s24),
                                Obx(() {
                                  final homeCtrl =
                                      Get.find<HomeScreenController>();
                                  final dailyButton = NeonIconButton(
                                    Icons.calendar_month_rounded,
                                    color: NeonTheme.red,
                                    size: 28,
                                    boxed: true,
                                    semanticLabel: 'daily_challenge_label'.tr,
                                    onTap: () {
                                      homeCtrl.dismissDailyChallengeTutorial();
                                      gameCtrl.startDailyChallenge();
                                      Get.to(() => const GameScreen());
                                    },
                                  );
                                  return CompositedTransformTarget(
                                    link: _dailyButtonLink,
                                    child:
                                        homeCtrl
                                            .showDailyChallengeTutorial
                                            .value
                                        ? PulseGlow(
                                            color: NeonTheme.red,
                                            child: dailyButton,
                                          )
                                        : dailyButton,
                                  );
                                }),
                                const SizedBox(width: NeonTheme.s24),
                                NeonIconButton(
                                  Icons.sports_esports_rounded,
                                  color: NeonTheme.indigo,
                                  size: 28,
                                  boxed: true,
                                  semanticLabel: 'modes_title'.tr,
                                  onTap: () =>
                                      Get.to(() => const ModeSelectScreen()),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                NeonIconButton(
                                  Icons.star_rounded,
                                  color: NeonTheme.yellow,
                                  size: 20,
                                  compact: true,
                                  semanticLabel: 'rate_app'.tr,
                                  onTap: () async {
                                    final review = InAppReview.instance;
                                    if (await review.isAvailable()) {
                                      await review.openStoreListing();
                                    }
                                  },
                                ),
                                NeonIconButton(
                                  Icons.apps_rounded,
                                  color: NeonTheme.indigo,
                                  size: 20,
                                  compact: true,
                                  semanticLabel: 'more_apps'.tr,
                                  onTap: () => launchUrl(
                                    Uri.parse(
                                      'https://play.google.com/store/apps/dev?id=6193840742938642798',
                                    ),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                ),
                                NeonIconButton(
                                  Icons.share_rounded,
                                  color: NeonTheme.cyan,
                                  size: 20,
                                  compact: true,
                                  semanticLabel: 'invite_friend'.tr,
                                  onTap: () => shareText(
                                    'invite_friend_share_msg'.trParams({
                                      'link':
                                          'https://play.google.com/store/apps/details?id=$kPackageName',
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: NeonTheme.s8,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    kCopyright,
                                    style: TextStyle(
                                      color: NeonTheme.ink.withValues(
                                        alpha: 0.45,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'v$kAppVersion+$kAppBuildNumber',
                                    style: TextStyle(
                                      color: NeonTheme.ink.withValues(
                                        alpha: 0.35,
                                      ),
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
                    ),
                  ),
                ),
                _ShopTutorialOverlay(gameCtrl: gameCtrl, link: _shopButtonLink),
                _DailyChallengeTutorialOverlay(link: _dailyButtonLink),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Round-7 Tutorial: coach-mark trỏ vào nút Shop trên hàng truy cập nhanh —
/// hiện lần đầu vào Home, tự tắt khi người chơi bấm vào Shop.
class _ShopTutorialOverlay extends StatelessWidget {
  const _ShopTutorialOverlay({required this.gameCtrl, required this.link});
  final GameController gameCtrl;
  final LayerLink link;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final homeCtrl = Get.find<HomeScreenController>();
      if (!homeCtrl.showShopTutorial.value) return const SizedBox.shrink();
      return IgnorePointer(
        child: CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          offset: const Offset(0, 8),
          child: _TutorialBubble(textKey: 'tutorial_shop_body'),
        ),
      );
    });
  }
}

/// I84: điều hướng cho từng loại gợi ý.
///
/// Mỗi nhánh dẫn tới **đúng chỗ mà entry point sẵn có đã dùng** (xem hàng nút
/// truy cập nhanh phía trên) — cố ý không tạo màn/dialog riêng cho dải này, để
/// không có 2 đường vào cùng một tính năng phải giữ đồng bộ.
void _onNextAction(
  BuildContext context,
  GameController gameCtrl,
  NextAction action,
) {
  switch (action.kind) {
    case NextActionKind.dailyReward:
      showLoginStreakDialog(context, gameCtrl);
    case NextActionKind.dailySpin:
      showSpinWheelDialog(context, gameCtrl);
    case NextActionKind.dailyQuest:
      showDailyQuestDialog(context, gameCtrl);
    case NextActionKind.raidBoss:
      Get.to(() => const RaidBossScreen());
    case NextActionKind.starRoadChest:
      Get.to(() => const StarRoadScreen());
    case NextActionKind.seasonMilestone:
      Get.to(() => const SeasonScreen());
    case NextActionKind.weeklyGoal:
      showWeeklyGoalDialog(context, gameCtrl);
    case NextActionKind.clanGoal:
      showClanDialog(context, gameCtrl);
    case NextActionKind.campaignLevel:
      Get.to(() => const LevelSelectScreen());
  }
}

/// Round-7 Tutorial: coach-mark trỏ vào nút Daily Challenge — chỉ hiện sau
/// khi tutorial Shop đã được xem, tránh chồng 2 tooltip cùng lúc.
class _DailyChallengeTutorialOverlay extends StatelessWidget {
  const _DailyChallengeTutorialOverlay({required this.link});
  final LayerLink link;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final homeCtrl = Get.find<HomeScreenController>();
      if (!homeCtrl.showDailyChallengeTutorial.value) {
        return const SizedBox.shrink();
      }
      return IgnorePointer(
        child: CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          offset: const Offset(0, 8),
          child: _TutorialBubble(textKey: 'tutorial_daily_challenge_body'),
        ),
      );
    });
  }
}

class _TutorialBubble extends StatelessWidget {
  const _TutorialBubble({required this.textKey});
  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: NeonTheme.s8,
      ),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: NeonTheme.drop(y: 3, blur: 8),
      ),
      child: Text(
        textKey.tr,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: NeonTheme.ink,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// I86: ghép digest vào lời nhắn comeback.
///
/// Nối vào message có sẵn thay vì mở khung riêng — digest rỗng thì popup y
/// hệt như trước, KHÔNG hiện khung trống.
String _comebackMessage(int reward) {
  final gameCtrl = Get.find<GameController>();
  final base = 'home_comeback_msg'.trParams({'coin': '$reward'});
  final lines = gameCtrl.comebackDigest(gameCtrl.lastComebackDaysAway);
  if (lines.isEmpty) return base;
  final body = lines.map((l) => '• ${l.key.trParams(l.params)}').join('\n');
  return '$base\n\n$body';
}
