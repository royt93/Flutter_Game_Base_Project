import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/battle_pass.dart' show RewardKind;
import '../../data/season.dart';
import '../controllers/game_controller.dart';
import '../controllers/season_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// Màn Sự kiện theo mùa — banner theme tuần + đếm ngược + mốc thưởng.
class SeasonScreen extends StatefulWidget {
  const SeasonScreen({super.key});

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
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
    final sc = Get.put(SeasonController(g));
    final accent = NeonTheme.accentForWorld(sc.worldAccent);
    return Scaffold(
      body: NeonBg(
        accent: accent,
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'season_title'.tr, color: accent),
              Expanded(
                child: Obx(() {
                  sc.points.value;
                  sc.claimed.length;
                  return ListView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    children: [
                      _banner(sc, accent),
                      const SizedBox(height: NeonTheme.s16),
                      for (int m = 0; m < kSeasonMilestones.length; m++)
                        _milestone(sc, m, accent),
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

  Widget _banner(SeasonController sc, Color accent) {
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
              Icon(Icons.event_rounded, color: accent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sc.seasonName(),
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
                '${'season_ends'.tr}: ${_fmtCountdown(sc.timeToEnd)}',
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
                '${sc.points.value} ${'season_points'.tr}',
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
  }

  Widget _milestone(SeasonController sc, int m, Color accent) {
    final ms = kSeasonMilestones[m];
    final reached = sc.isReached(m);
    final claimed = sc.isClaimed(m);
    final canClaim = sc.canClaim(m);
    final p = sc.points.value.clamp(0, ms.points);
    final prev = m == 0 ? 0 : kSeasonMilestones[m - 1].points;
    final span = (ms.points - prev).clamp(1, 1 << 30);
    final into = (sc.points.value - prev).clamp(0, span);
    return Container(
      margin: const EdgeInsets.only(bottom: NeonTheme.s8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: reached ? 0.7 : 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: claimed
                ? Colors.grey
                : (reached ? NeonTheme.lime : accent),
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
                  onTap: () => sc.claim(m),
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

  IconData _rewardIcon(RewardKind k) {
    switch (k) {
      case RewardKind.coins:
        return Icons.monetization_on_rounded;
      case RewardKind.hammer:
        return Icons.gavel_rounded;
      case RewardKind.moves:
        return Icons.add_circle_rounded;
      default: // season không dùng booster độc quyền
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
