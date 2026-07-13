import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../../data/leaderboard_bots.dart';
import '../../logic/leaderboard.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// I9: bảng xếp hạng offline giả lập — chỉ so với [kLeaderboardBots] tĩnh,
/// không có backend/network/bạn bè thật.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              const NeonAppBar(title: 'Leaderboard', color: NeonTheme.teal),
              Expanded(
                child: Obx(() {
                  final entries = buildLeaderboard(
                    kLeaderboardBots,
                    gameCtrl.totalStars.value,
                  );
                  return ListView.builder(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: NeonTheme.s8),
                      child: _RankRow(rank: i + 1, entry: entries[i]),
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

class _RankRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;

  const _RankRow({required this.rank, required this.entry});

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
              entry.isPlayer ? 'You' : entry.name,
              style: TextStyle(
                color: NeonTheme.ink,
                fontWeight: entry.isPlayer ? FontWeight.w800 : FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          Icon(Icons.star_rounded, color: NeonTheme.gold, size: 18),
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
