import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/tournament.dart';
import '../controllers/game_controller.dart';
import '../controllers/tournament_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// Giải đấu tuần — bảng xếp hạng (người chơi + 7 bot) + đếm ngược + thưởng hạng.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _fmtCountdown(Duration d) {
    final days = d.inDays;
    final h = d.inHours.remainder(24).toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return days > 0 ? '${days}d $h:$m:$s' : '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final g = Get.find<GameController>();
    final tc = Get.put(TournamentController(g));
    const accent = NeonTheme.orange;
    return Scaffold(
      body: NeonBg(
        accent: accent,
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'tour_title'.tr,
                color: accent,
                actions: [CoinChip(g)],
              ),
              Expanded(
                child: Obx(() {
                  tc.points.value;
                  tc.claimedThisWeek.value;
                  // Xây bảng xếp hạng: người chơi + 7 bot, sắp giảm dần theo điểm.
                  final entries = <_Entry>[
                    _Entry('tour_you'.tr, tc.points.value, true),
                    for (int i = 0; i < kTournamentBots.length; i++)
                      _Entry(kTournamentBots[i].name, tc.botScoreNow(i), false),
                  ]..sort((a, b) => b.score.compareTo(a.score));
                  return ListView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    children: [
                      _banner(tc, accent),
                      const SizedBox(height: NeonTheme.s16),
                      for (int r = 0; r < entries.length; r++)
                        _row(r + 1, entries[r], accent),
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

  Widget _banner(TournamentController tc, Color accent) {
    final reward = tc.pendingReward;
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent, width: 1.5),
        boxShadow: NeonTheme.glow(accent, blur: 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: accent, size: 24),
              const SizedBox(width: 8),
              Text(
                'tour_rank'.trParams({'n': '${tc.playerRank}'}),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: accent, blurRadius: 12)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  color: Colors.white.withValues(alpha: 0.8), size: 16),
              const SizedBox(width: 5),
              Text(
                '${'tour_ends'.tr}: ${_fmtCountdown(tc.timeToEnd)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
              const SizedBox(width: 5),
              Text(
                '${tc.points.value} ${'tour_points'.tr}',
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          if (tc.claimedThisWeek.value)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.grey, size: 18),
                const SizedBox(width: 6),
                Text(
                  'tour_claimed'.tr,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: tc.canClaim ? () => tc.claim() : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tc.canClaim
                      ? NeonTheme.lime.withValues(alpha: 0.2)
                      : NeonTheme.panel.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tc.canClaim ? NeonTheme.lime : Colors.white24,
                    width: 1.5,
                  ),
                  boxShadow:
                      tc.canClaim ? NeonTheme.glow(NeonTheme.lime, blur: 8) : null,
                ),
                child: Text(
                  tc.canClaim
                      ? 'tour_claim_reward'
                          .trParams({'n': fmtNum(reward.amount)})
                      : 'tour_play_hint'.tr,
                  style: TextStyle(
                    color: tc.canClaim ? NeonTheme.lime : Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(int rank, _Entry e, Color accent) {
    final medal = rank <= 3;
    final medalColor = rank == 1
        ? NeonTheme.yellow
        : rank == 2
            ? Colors.white70
            : NeonTheme.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: NeonTheme.s8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: e.isPlayer
            ? accent.withValues(alpha: 0.18)
            : NeonTheme.panel.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: e.isPlayer ? accent : Colors.white12,
          width: e.isPlayer ? 1.8 : 1,
        ),
        boxShadow: e.isPlayer ? NeonTheme.glow(accent, blur: 8) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: medal
                ? Icon(Icons.workspace_premium_rounded,
                    color: medalColor, size: 22)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: e.isPlayer ? accent : Colors.white,
                fontSize: 15,
                fontWeight: e.isPlayer ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            fmtNum(e.score),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry {
  final String name;
  final int score;
  final bool isPlayer;
  _Entry(this.name, this.score, this.isPlayer);
}
