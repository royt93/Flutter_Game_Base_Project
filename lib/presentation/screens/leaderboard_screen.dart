import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/daily_challenge_leaderboard_bots.dart';
import '../../data/leaderboard_bots.dart';
import '../../logic/leaderboard.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// I9: bảng xếp hạng offline giả lập — chỉ so với [kLeaderboardBots] /
/// [kDailyChallengeLeaderboardBots] tĩnh, không có backend/network/bạn bè thật.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _showDaily = false;

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
                        selected: !_showDaily,
                        onTap: () => setState(() => _showDaily = false),
                      ),
                    ),
                    const SizedBox(width: NeonTheme.s8),
                    Expanded(
                      child: _TabChip(
                        icon: Icons.bolt_rounded,
                        selected: _showDaily,
                        onTap: () => setState(() => _showDaily = true),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  final entries = _showDaily
                      ? buildLeaderboard(
                          kDailyChallengeLeaderboardBots,
                          gameCtrl.dailyChallengeScoreForLeaderboard,
                        )
                      : buildLeaderboard(
                          kLeaderboardBots,
                          gameCtrl.totalStars.value,
                        );
                  return ListView.builder(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: NeonTheme.s8),
                      child: _RankRow(
                        rank: i + 1,
                        entry: entries[i],
                        icon: _showDaily
                            ? Icons.bolt_rounded
                            : Icons.star_rounded,
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

  const _RankRow({required this.rank, required this.entry, required this.icon});

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
              entry.isPlayer ? 'leaderboard_you'.tr : entry.name,
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
