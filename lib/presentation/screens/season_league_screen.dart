import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/battle_pass.dart' show RewardKind;
import '../../data/season.dart';
import '../../data/tournament.dart';
import '../controllers/game_controller.dart';
import '../controllers/season_league_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// W18.1 — Mùa giải (gộp Mùa + Giải đấu): 1 đường điểm, 2 trục thưởng.
/// Trên: banner mùa + trục MỐC (6 mốc). Dưới: trục HẠNG (bảng 7 bot + thưởng hạng).
class SeasonLeagueScreen extends StatefulWidget {
  const SeasonLeagueScreen({super.key});

  @override
  State<SeasonLeagueScreen> createState() => _SeasonLeagueScreenState();
}

class _SeasonLeagueScreenState extends State<SeasonLeagueScreen> {
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
    final lc = Get.put(SeasonLeagueController(g), permanent: true);
    final accent = NeonTheme.accentForWorld(lc.worldAccent);
    return Scaffold(
      body: NeonBg(
        accent: accent,
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'season_title'.tr,
                color: accent,
                actions: [CoinChip(g)],
              ),
              Expanded(
                child: Obx(() {
                  lc.points.value;
                  lc.claimedMilestones.length;
                  lc.claimedRankThisWeek.value;
                  final entries = <_Entry>[
                    _Entry('tour_you'.tr, lc.points.value, true),
                    for (int i = 0; i < kTournamentBots.length; i++)
                      _Entry(kTournamentBots[i].name, lc.botScoreNow(i), false),
                  ]..sort((a, b) => b.score.compareTo(a.score));
                  return ListView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    children: [
                      _seasonBanner(lc, accent),
                      const SizedBox(height: NeonTheme.s16),
                      // Trục MỐC
                      for (int m = 0; m < kSeasonMilestones.length; m++)
                        _milestone(lc, m, accent),
                      const SizedBox(height: NeonTheme.s16),
                      // Trục HẠNG
                      _rankBanner(lc, NeonTheme.orange),
                      const SizedBox(height: NeonTheme.s8),
                      for (int r = 0; r < entries.length; r++)
                        _row(r + 1, entries[r], NeonTheme.orange),
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

  Widget _seasonBanner(SeasonLeagueController lc, Color accent) => Container(
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
                Icon(Icons.event_rounded, color: accent, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lc.seasonName(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: accent, blurRadius: 12)],
                    ),
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
                  '${'season_ends'.tr}: ${_fmtCountdown(lc.timeToEnd)}',
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
                Icon(Icons.local_fire_department_rounded, color: accent, size: 18),
                const SizedBox(width: 5),
                Text(
                  '${lc.points.value} ${'season_points'.tr}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'season_hint'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _milestone(SeasonLeagueController lc, int m, Color accent) {
    final ms = kSeasonMilestones[m];
    final reached = lc.isReached(m);
    final claimed = lc.isClaimed(m);
    final canClaim = lc.canClaimMilestone(m);
    final p = lc.points.value.clamp(0, ms.points);
    final prev = m == 0 ? 0 : kSeasonMilestones[m - 1].points;
    final span = (ms.points - prev).clamp(1, 1 << 30);
    final into = (lc.points.value - prev).clamp(0, span);
    return Container(
      margin: const EdgeInsets.only(bottom: NeonTheme.s8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: reached ? 0.7 : 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: claimed ? Colors.grey : (reached ? NeonTheme.lime : accent),
            width: 1.5),
        boxShadow: canClaim ? NeonTheme.glow(NeonTheme.lime, blur: 8) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_rewardIcon(ms.kind), color: _rewardColor(ms.kind), size: 20),
              const SizedBox(width: 6),
              Text(
                '${fmtNum(ms.amount)} ${_rewardLabel(ms.kind)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (claimed)
                const Icon(Icons.check_rounded, color: Colors.grey, size: 22)
              else if (canClaim)
                GestureDetector(
                  onTap: () => lc.claimMilestone(m),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: NeonTheme.lime.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NeonTheme.lime, width: 1.5),
                    ),
                    child: Text('daily_claim'.tr,
                        style: const TextStyle(
                          color: NeonTheme.lime,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                )
              else
                Text('${ms.points} ${'season_pts_short'.tr}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: into / span,
              minHeight: 6,
              backgroundColor: NeonTheme.bgDark2,
              valueColor: AlwaysStoppedAnimation<Color>(
                  reached ? NeonTheme.lime : accent),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text('$p/${ms.points}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }

  Widget _rankBanner(SeasonLeagueController lc, Color accent) {
    final reward = lc.pendingRankReward;
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
                'tour_rank'.trParams({'n': '${lc.playerRank}'}),
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
                '${'tour_ends'.tr}: ${_fmtCountdown(lc.timeToEnd)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          if (lc.claimedRankThisWeek.value)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.grey, size: 18),
                const SizedBox(width: 6),
                Text('tour_claimed'.tr,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            )
          else
            GestureDetector(
              onTap: lc.canClaimRank ? () => lc.claimRank() : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lc.canClaimRank
                      ? NeonTheme.lime.withValues(alpha: 0.2)
                      : NeonTheme.panel.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: lc.canClaimRank ? NeonTheme.lime : Colors.white24,
                    width: 1.5,
                  ),
                  boxShadow: lc.canClaimRank
                      ? NeonTheme.glow(NeonTheme.lime, blur: 8)
                      : null,
                ),
                child: Text(
                  lc.canClaimRank
                      ? 'tour_claim_reward'.trParams({'n': fmtNum(reward.amount)})
                      : 'tour_play_hint'.tr,
                  style: TextStyle(
                    color: lc.canClaimRank ? NeonTheme.lime : Colors.white54,
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
                : Text('$rank',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    )),
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

  IconData _rewardIcon(RewardKind k) {
    switch (k) {
      case RewardKind.coins:
        return Icons.monetization_on_rounded;
      case RewardKind.hammer:
        return Icons.gavel_rounded;
      case RewardKind.moves:
        return Icons.add_circle_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  Color _rewardColor(RewardKind k) {
    switch (k) {
      case RewardKind.coins:
        return NeonTheme.yellow;
      case RewardKind.hammer:
        return NeonTheme.magenta;
      case RewardKind.moves:
        return NeonTheme.lime;
      default:
        return NeonTheme.purple;
    }
  }

  String _rewardLabel(RewardKind k) {
    switch (k) {
      case RewardKind.coins:
        return 'coins_short'.tr;
      case RewardKind.hammer:
        return 'bp_hammer'.tr;
      case RewardKind.moves:
        return 'bp_moves'.tr;
      default:
        return 'bp_color'.tr;
    }
  }
}

class _Entry {
  final String name;
  final int score;
  final bool isPlayer;
  _Entry(this.name, this.score, this.isPlayer);
}
