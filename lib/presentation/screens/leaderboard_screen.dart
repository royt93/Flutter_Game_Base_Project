import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/daily_challenge_leaderboard_bots.dart';
import '../../data/gauntlet_leaderboard_bots.dart';
import '../../data/leaderboard_bots.dart';
import '../../data/weekly_featured_leaderboard_bots.dart';
import '../../logic/leaderboard.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

enum _LeaderboardTab { campaign, dailyChallenge, gauntlet, weeklyFeatured }

/// I9: bảng xếp hạng offline giả lập — chỉ so với [kLeaderboardBots] /
/// [kDailyChallengeLeaderboardBots] / [kGauntletLeaderboardBots] tĩnh, không
/// có backend/network/bạn bè thật.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  _LeaderboardTab _tab = _LeaderboardTab.campaign;

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'leaderboard_title'.tr, color: NeonTheme.teal),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NeonTheme.s16,
                  vertical: NeonTheme.s8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabChip(
                        icon: Icons.star_rounded,
                        selected: _tab == _LeaderboardTab.campaign,
                        onTap: () =>
                            setState(() => _tab = _LeaderboardTab.campaign),
                      ),
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    Expanded(
                      child: _TabChip(
                        icon: Icons.bolt_rounded,
                        selected: _tab == _LeaderboardTab.dailyChallenge,
                        onTap: () => setState(
                          () => _tab = _LeaderboardTab.dailyChallenge,
                        ),
                      ),
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    Expanded(
                      child: _TabChip(
                        icon: Icons.whatshot_rounded,
                        selected: _tab == _LeaderboardTab.gauntlet,
                        onTap: () =>
                            setState(() => _tab = _LeaderboardTab.gauntlet),
                      ),
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    Expanded(
                      child: _TabChip(
                        icon: Icons.event_rounded,
                        selected: _tab == _LeaderboardTab.weeklyFeatured,
                        onTap: () => setState(
                          () => _tab = _LeaderboardTab.weeklyFeatured,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  final icon = switch (_tab) {
                    _LeaderboardTab.campaign => Icons.star_rounded,
                    _LeaderboardTab.dailyChallenge => Icons.bolt_rounded,
                    _LeaderboardTab.gauntlet => Icons.whatshot_rounded,
                    _LeaderboardTab.weeklyFeatured => Icons.event_rounded,
                  };
                  final entries = switch (_tab) {
                    _LeaderboardTab.campaign => buildLeaderboard(
                      kLeaderboardBots,
                      gameCtrl.totalStars.value,
                    ),
                    _LeaderboardTab.dailyChallenge => buildLeaderboard(
                      kDailyChallengeLeaderboardBots,
                      gameCtrl.dailyChallengeScoreForLeaderboard,
                    ),
                    _LeaderboardTab.gauntlet => buildLeaderboard(
                      kGauntletLeaderboardBots,
                      gameCtrl.gauntletScoreForLeaderboard,
                    ),
                    _LeaderboardTab.weeklyFeatured => buildLeaderboard(
                      kWeeklyFeaturedLeaderboardBots,
                      gameCtrl.featuredLevelScore,
                    ),
                  };
                  final playerTitle = gameCtrl.activeTitleAchievement;
                  return ListView.builder(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: NeonTheme.s8),
                      child: _RankRow(
                        rank: i + 1,
                        entry: entries[i],
                        icon: icon,
                        playerTitleKey: entries[i].isPlayer
                            ? playerTitle?.titleKey
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? NeonTheme.teal : NeonTheme.inkSoft;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: NeonTheme.s8),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: selected ? 2 : 1),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final IconData icon;
  final String? playerTitleKey;

  const _RankRow({
    required this.rank,
    required this.entry,
    required this.icon,
    this.playerTitleKey,
  });

  @override
  Widget build(BuildContext context) {
    final color = entry.isPlayer ? NeonTheme.gold : NeonTheme.teal;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: NeonTheme.s8,
      ),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: entry.isPlayer ? 2.5 : 1.5),
        boxShadow: entry.isPlayer ? NeonTheme.glow(color) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.isPlayer
                  ? playerTitleKey == null
                        ? 'leaderboard_you'.tr
                        : '${'leaderboard_you'.tr} · ${playerTitleKey!.tr}'
                  : entry.name,
              style: TextStyle(
                color: NeonTheme.ink,
                fontWeight: entry.isPlayer ? FontWeight.w800 : FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          Icon(icon, color: NeonTheme.gold, size: 18),
          const SizedBox(width: 4),
          Text(
            '${entry.stars}',
            style: TextStyle(
              color: NeonTheme.inkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
