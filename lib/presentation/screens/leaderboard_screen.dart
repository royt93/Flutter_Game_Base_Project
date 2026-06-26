import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/leaderboard_engine.dart';
import '../../core/neon_theme.dart';
import '../controllers/game_controller.dart';
import '../controllers/leaderboard_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// Bảng xếp hạng offline (Wave 21.6) — 2 tab Campaign / Daily, bot tất định.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = Get.find<GameController>();
    // find trước (đã permanent từ Home); fallback put nếu test mount độc lập.
    final lb = Get.isRegistered<LeaderboardController>()
        ? Get.find<LeaderboardController>()
        : Get.put(LeaderboardController(g));
    const accent = NeonTheme.yellow;
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'leaderboard_title'.tr,
                color: accent,
                actions: [CoinChip(g)],
              ),
              _tabs(lb, accent),
              Expanded(
                child: Obx(() {
                  final isCampaign = lb.tab.value == 0;
                  lb.selectedLevel.value; // đọc để rebuild khi đổi màn
                  g.highScores.length; // rebuild khi điểm thật đổi
                  final board = isCampaign
                      ? lb.campaignBoard()
                      : lb.dailyBoard();
                  return ListView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    children: [
                      if (isCampaign) _levelPicker(lb, accent),
                      // Daily: chỉ nhắc "hoàn thành Daily" khi người chơi chưa có điểm.
                      if (!isCampaign && playerRank(board) == 0) _dailyNote(),
                      const SizedBox(height: NeonTheme.s8),
                      for (var i = 0; i < board.length; i++)
                        _row(i + 1, board[i], accent),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs(LeaderboardController lb, Color accent) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: NeonTheme.s16),
    child: Obx(
      () => Row(
        children: [
          _tabBtn(lb, 0, 'lb_tab_campaign'.tr, accent),
          const SizedBox(width: NeonTheme.s8),
          _tabBtn(lb, 1, 'lb_tab_daily'.tr, accent),
        ],
      ),
    ),
  );

  Widget _tabBtn(
    LeaderboardController lb,
    int idx,
    String label,
    Color accent,
  ) {
    final on = lb.tab.value == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => lb.tab.value = idx,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? accent.withValues(alpha: 0.18) : NeonTheme.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? accent : Colors.white24,
              width: on ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: on ? accent : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _levelPicker(LeaderboardController lb, Color accent) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: NeonTheme.s16,
      vertical: NeonTheme.s8,
    ),
    decoration: BoxDecoration(
      color: NeonTheme.panel.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent, width: 1.2),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => lb.setLevel(lb.selectedLevel.value - 1),
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
        ),
        Text(
          '${'lb_level'.tr} ${lb.selectedLevel.value} / ${lb.maxLevel}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        IconButton(
          onPressed: () => lb.setLevel(lb.selectedLevel.value + 1),
          icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ),
      ],
    ),
  );

  Widget _dailyNote() => Padding(
    padding: const EdgeInsets.symmetric(vertical: NeonTheme.s8),
    child: Text(
      'lb_daily_note'.tr,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white60, fontSize: 12),
    ),
  );

  Widget _row(int rank, LbEntry e, Color accent) {
    final color = e.isPlayer ? accent : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: NeonTheme.s8),
      padding: const EdgeInsets.symmetric(
        horizontal: NeonTheme.s16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: e.isPlayer
            ? accent.withValues(alpha: 0.16)
            : NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: e.isPlayer ? accent : Colors.white12,
          width: e.isPlayer ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank <= 3 ? accent : Colors.white54,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              e.isPlayer ? 'lb_player'.tr : e.name,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${e.score}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
