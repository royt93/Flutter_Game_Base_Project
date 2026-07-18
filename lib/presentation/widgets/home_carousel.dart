import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../core/utils/weekend_event.dart';
import '../../data/achievements.dart';
import '../../data/perks.dart';
import '../controllers/game_controller.dart';
import '../screens/achievements_screen.dart';
import '../screens/perks_screen.dart';
import '../screens/season_screen.dart';
import '../screens/star_road_screen.dart';

/// X14: carousel tiến độ thật trên Home, thay cho banner ưu tiên đơn cũ (X9).
enum HomeCardType { greeting, starRoad, seasonPass, achievement, perk }

/// 1 thẻ trong [HomeCarousel]. Text là hàm nhận `BuildContext` (không phải
/// `String` thô) vì phụ thuộc `.tr`/locale hiện tại và số liệu động — build
/// đúng lúc render, không cache.
class HomeCardData {
  const HomeCardData({
    required this.type,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.icon,
    required this.accentColor,
    this.ctaLabelBuilder,
    required this.onTap,
    this.badgeTextBuilder,
  });

  final HomeCardType type;
  final String Function(BuildContext) titleBuilder;
  final String Function(BuildContext) subtitleBuilder;
  final IconData icon;
  final Color accentColor;
  final String Function(BuildContext)? ctaLabelBuilder;
  final VoidCallback onTap;
  final String Function(BuildContext)? badgeTextBuilder;
}

/// Hàm thuần: tính danh sách card hiện tại từ state thật của [gameCtrl].
/// Thứ tự cố định theo loại: greeting luôn có (index 0), rồi starRoad >
/// seasonPass > achievement > perk — mỗi loại chỉ xuất hiện nếu "đáng chú ý".
List<HomeCardData> buildHomeCards(GameController gameCtrl) {
  final cards = <HomeCardData>[_greetingCard(gameCtrl)];
  final starRoad = _starRoadCard(gameCtrl);
  if (starRoad != null) cards.add(starRoad);
  final season = _seasonCard(gameCtrl);
  if (season != null) cards.add(season);
  final achievement = _achievementCard(gameCtrl);
  if (achievement != null) cards.add(achievement);
  final perk = _perkCard(gameCtrl);
  if (perk != null) cards.add(perk);
  return cards;
}

HomeCardData _greetingCard(GameController gameCtrl) {
  final hour = DateTime.now().hour;
  final greetingKey = hour < 11
      ? 'home_greeting_morning'
      : (hour < 18 ? 'home_greeting_afternoon' : 'home_greeting_evening');
  final weekend = isWeekendEvent(DateTime.now());
  return HomeCardData(
    type: HomeCardType.greeting,
    titleBuilder: (_) => greetingKey.tr,
    subtitleBuilder: (_) {
      if (gameCtrl.canClaimDaily) return 'daily_claim'.tr;
      if (gameCtrl.dailyStreak.value > 0) {
        return 'home_daily_streak'.trParams({
          'n': '${gameCtrl.dailyStreak.value}',
        });
      }
      return '';
    },
    icon: Icons.wb_sunny_rounded,
    accentColor: weekend ? NeonTheme.gold : NeonTheme.cyan,
    ctaLabelBuilder: gameCtrl.canClaimDaily ? (_) => 'daily_claim'.tr : null,
    onTap: gameCtrl.canClaimDaily ? () => gameCtrl.claimDaily() : () {},
    badgeTextBuilder: weekend ? (_) => 'home_weekend_badge'.tr : null,
  );
}

HomeCardData? _starRoadCard(GameController gameCtrl) {
  final claimableIndex = List.generate(
    GameController.starRoadMilestones.length,
    (i) => i,
  ).where(gameCtrl.canClaimChest).toList();
  final nextMilestone = GameController.starRoadMilestones
      .where((m) => m > gameCtrl.totalStars.value)
      .fold<int?>(null, (best, m) => best == null || m < best ? m : best);
  final distance = nextMilestone == null
      ? null
      : nextMilestone - gameCtrl.totalStars.value;
  final notable =
      claimableIndex.isNotEmpty || (distance != null && distance <= 3);
  if (!notable) return null;
  final claimIndex = claimableIndex.isNotEmpty ? claimableIndex.first : null;
  return HomeCardData(
    type: HomeCardType.starRoad,
    titleBuilder: (_) => 'star_road_title'.tr,
    subtitleBuilder: (_) => claimIndex != null
        ? 'home_star_road_claim'.tr
        : 'home_star_road_progress'.trParams({'n': '$distance'}),
    icon: Icons.auto_awesome_rounded,
    accentColor: NeonTheme.gold,
    ctaLabelBuilder: claimIndex != null
        ? (_) => 'home_star_road_claim'.tr
        : null,
    onTap: claimIndex != null
        ? () => gameCtrl.claimChest(claimIndex)
        : () => Get.to(() => const StarRoadScreen()),
  );
}

HomeCardData? _seasonCard(GameController gameCtrl) {
  final claimableIndex = List.generate(
    GameController.seasonMilestones.length,
    (i) => i,
  ).where(gameCtrl.canClaimSeason).toList();
  final nextMilestone = GameController.seasonMilestones
      .where((m) => m > gameCtrl.seasonPoints.value)
      .fold<int?>(null, (best, m) => best == null || m < best ? m : best);
  final distance = nextMilestone == null
      ? null
      : nextMilestone - gameCtrl.seasonPoints.value;
  final notable =
      claimableIndex.isNotEmpty || (distance != null && distance <= 20);
  if (!notable) return null;
  final claimIndex = claimableIndex.isNotEmpty ? claimableIndex.first : null;
  return HomeCardData(
    type: HomeCardType.seasonPass,
    titleBuilder: (_) => 'season_pass_title'.tr,
    subtitleBuilder: (_) => claimIndex != null
        ? 'home_season_claim'.tr
        : 'home_season_progress'.trParams({'n': '$distance'}),
    icon: Icons.military_tech_rounded,
    accentColor: NeonTheme.magenta,
    ctaLabelBuilder: claimIndex != null ? (_) => 'home_season_claim'.tr : null,
    onTap: claimIndex != null
        ? () => gameCtrl.claimSeason(claimIndex)
        : () => Get.to(() => const SeasonScreen()),
  );
}

HomeCardData? _achievementCard(GameController gameCtrl) {
  final justUnlocked = gameCtrl.justUnlockedAchievement.value;
  if (justUnlocked != null) {
    return HomeCardData(
      type: HomeCardType.achievement,
      titleBuilder: (_) => 'achievements_title'.tr,
      subtitleBuilder: (_) => 'home_achievement_unlocked'.trParams({
        'name': justUnlocked.titleKey.tr,
      }),
      icon: Icons.emoji_events_rounded,
      accentColor: NeonTheme.gold,
      onTap: () => Get.to(() => const AchievementsScreen()),
    );
  }
  Achievement? best;
  var bestRatio = 0.0;
  for (final a in kAchievements) {
    if (gameCtrl.unlockedAchievementIds.contains(a.id)) continue;
    final ratio = gameCtrl.metricValue(a.metric) / a.threshold;
    if (ratio >= 0.8 && ratio > bestRatio) {
      bestRatio = ratio;
      best = a;
    }
  }
  if (best == null) return null;
  return HomeCardData(
    type: HomeCardType.achievement,
    titleBuilder: (_) => 'achievements_title'.tr,
    subtitleBuilder: (_) =>
        'home_achievement_progress'.trParams({'name': best!.titleKey.tr}),
    icon: Icons.emoji_events_rounded,
    accentColor: NeonTheme.gold,
    onTap: () => Get.to(() => const AchievementsScreen()),
  );
}

HomeCardData? _perkCard(GameController gameCtrl) {
  final hasInactivePerk =
      gameCtrl.unlockedPerksList.length > gameCtrl.activePerkIds.length;
  final done = worldsCompleted(gameCtrl.unlockedLevel.value);
  final nextLockedPerk = kPerks
      .where((p) => !gameCtrl.unlockedPerksList.any((u) => u.id == p.id))
      .fold<Perk?>(
        null,
        (best, p) => best == null || p.unlockAfterWorld < best.unlockAfterWorld
            ? p
            : best,
      );
  final worldsAway = nextLockedPerk == null
      ? null
      : nextLockedPerk.unlockAfterWorld - done;
  final notable = hasInactivePerk || worldsAway == 1;
  if (!notable) return null;
  return HomeCardData(
    type: HomeCardType.perk,
    titleBuilder: (_) => 'perks_title'.tr,
    subtitleBuilder: (_) => hasInactivePerk
        ? 'home_perk_activate_reminder'.tr
        : 'home_perk_progress'.trParams({'n': '$worldsAway'}),
    icon: Icons.auto_fix_high_rounded,
    accentColor: NeonTheme.pink,
    onTap: () => Get.to(() => const PerksScreen()),
  );
}

/// PageView tiến độ thật, dot-indicator tự vẽ. Đọc `controller.cards`/
/// `controller.currentIndex` qua `Obx`.
class HomeCarousel extends StatelessWidget {
  const HomeCarousel({
    super.key,
    required this.cards,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onCardTapped,
  });

  final List<HomeCardData> cards;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  /// Gọi ngay sau khi 1 card được tap (sau `data.onTap()`) — dùng để refresh
  /// lại danh sách card, vì `ctaLabelBuilder`/`onTap` của mỗi card được chốt
  /// 1 lần lúc build danh sách (không tự re-evaluate), nên sau 1 hành động
  /// claim (daily/chest/season) phải rebuild lại để CTA không bị "kẹt".
  final VoidCallback onCardTapped;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          // +NeonTheme.s8 so the badge's `Positioned(top: -8, ...)` in
          // _HomeCard has room to render — PageView's Viewport clips to its
          // own bounds regardless of the inner Stack's Clip.none, so without
          // this the badge's top edge gets cut off.
          height: 92 + NeonTheme.s8,
          child: PageView.builder(
            itemCount: cards.length,
            onPageChanged: onPageChanged,
            controller: PageController(viewportFraction: 0.92),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.fromLTRB(
                NeonTheme.s8,
                NeonTheme.s8,
                NeonTheme.s8,
                0,
              ),
              child: _HomeCard(data: cards[i], onTapped: onCardTapped),
            ),
          ),
        ),
        if (cards.length > 1) ...[
          const SizedBox(height: NeonTheme.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (i) {
              final active = i == currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? cards[currentIndex].accentColor
                      : NeonTheme.inkSoft.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.data, required this.onTapped});

  final HomeCardData data;
  final VoidCallback onTapped;

  @override
  Widget build(BuildContext context) {
    final badge = data.badgeTextBuilder?.call(context);
    final cta = data.ctaLabelBuilder?.call(context);
    return GestureDetector(
      onTap: () {
        data.onTap();
        onTapped();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(NeonTheme.s16),
            decoration: BoxDecoration(
              color: NeonTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: data.accentColor, width: 2),
              boxShadow: NeonTheme.drop(),
            ),
            child: Row(
              children: [
                Icon(data.icon, color: data.accentColor, size: 32),
                const SizedBox(width: NeonTheme.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.titleBuilder(context),
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (data.subtitleBuilder(context).isNotEmpty)
                        Text(
                          data.subtitleBuilder(context),
                          style: TextStyle(
                            color: NeonTheme.inkSoft,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (cta != null) ...[
                  const SizedBox(width: NeonTheme.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NeonTheme.s16,
                      vertical: NeonTheme.s8,
                    ),
                    decoration: BoxDecoration(
                      color: data.accentColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      cta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -8,
              right: NeonTheme.s16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: data.accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
