import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../../data/battle_pass.dart';
import '../controllers/battle_pass_controller.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// Màn Battle Pass: 3 nhiệm vụ ngày (trên) + track thưởng theo cấp (dưới).
class BattlePassScreen extends StatelessWidget {
  const BattlePassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = Get.find<GameController>();
    final bp = Get.put(BattlePassController(g));
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'bp_title'.tr, color: NeonTheme.orange),
              Expanded(
                child: Obx(() {
                  bp.xp.value;
                  bp.claimed.length;
                  bp.questProgress.length;
                  return ListView(
                    padding: const EdgeInsets.all(NeonTheme.s16),
                    children: [
                      _xpHeader(bp),
                      const SizedBox(height: NeonTheme.s16),
                      _sectionTitle('quest_daily'.tr),
                      const SizedBox(height: NeonTheme.s8),
                      for (int i = 0; i < bp.todayQuests.length; i++)
                        _questCard(bp, i),
                      const SizedBox(height: NeonTheme.s24),
                      _sectionTitle('bp_track'.tr),
                      const SizedBox(height: NeonTheme.s8),
                      for (int i = 0; i < kPassTiers.length; i++)
                        _tierCard(bp, i),
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

  Widget _sectionTitle(String s) => Text(
        s,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      );

  Widget _xpHeader(BattlePassController bp) {
    final max = bp.level >= kPassTiers.length;
    final cur = kPassTiers[bp.level.clamp(0, kPassTiers.length - 1)];
    final prevNeeded = bp.level == 0 ? 0 : kPassTiers[bp.level - 1].xpNeeded;
    final span = (cur.xpNeeded - prevNeeded).clamp(1, 1 << 30);
    final into = (bp.xp.value - prevNeeded).clamp(0, span);
    return Container(
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeonTheme.orange, width: 1.5),
        boxShadow: NeonTheme.glow(NeonTheme.orange, blur: 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded,
                  color: NeonTheme.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                '${'bp_level'.tr} ${bp.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                max ? 'temple_maxed'.tr : '${bp.xp.value} XP',
                style: TextStyle(
                  color: NeonTheme.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: max ? 1 : into / span,
              minHeight: 8,
              backgroundColor: NeonTheme.bgDark2,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(NeonTheme.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questCard(BattlePassController bp, int i) {
    final q = bp.todayQuests[i];
    final p = bp.questProgress[i].clamp(0, q.target);
    final done = bp.questDone(i);
    return Container(
      margin: const EdgeInsets.only(bottom: NeonTheme.s8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done ? NeonTheme.lime : NeonTheme.cyan,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(done ? Icons.check_circle_rounded : Icons.flag_rounded,
                  color: done ? NeonTheme.lime : NeonTheme.cyan, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  q.descKey.trParams({'n': '${q.target}'}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '+${q.xp} XP',
                style: const TextStyle(
                  color: NeonTheme.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: q.target == 0 ? 1 : p / q.target,
                    minHeight: 6,
                    backgroundColor: NeonTheme.bgDark2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        done ? NeonTheme.lime : NeonTheme.cyan),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$p/${q.target}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tierCard(BattlePassController bp, int i) {
    final t = kPassTiers[i];
    final reached = bp.isReached(i);
    final claimed = bp.isClaimed(i);
    final canClaim = bp.canClaim(i);
    final color = claimed
        ? Colors.grey
        : (reached ? NeonTheme.lime : NeonTheme.cyan);
    return Container(
      margin: const EdgeInsets.only(bottom: NeonTheme.s8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: reached ? 0.7 : 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
        boxShadow: canClaim ? NeonTheme.glow(NeonTheme.lime, blur: 8) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Text(
              '${i + 1}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(_rewardIcon(t.kind), color: _rewardColor(t.kind), size: 20),
          const SizedBox(width: 6),
          Text(
            '${fmtNum(t.amount)} ${_rewardLabel(t.kind)}',
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
              onTap: () => bp.claim(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: NeonTheme.lime.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NeonTheme.lime, width: 1.5),
                ),
                child: Text(
                  'daily_claim'.tr,
                  style: const TextStyle(
                    color: NeonTheme.lime,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else
            Text(
              '${t.xpNeeded} XP',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
      case RewardKind.color:
        return Icons.palette_rounded;
      case RewardKind.joker:
        return Icons.style_rounded;
      case RewardKind.lightning:
        return Icons.bolt_rounded;
      case RewardKind.royal:
        return Icons.workspace_premium_rounded;
      case RewardKind.gravity:
        return Icons.swap_vert_rounded;
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
      case RewardKind.color:
        return NeonTheme.purple;
      case RewardKind.joker:
        return NeonTheme.magenta;
      case RewardKind.lightning:
        return NeonTheme.yellow;
      case RewardKind.royal:
        return NeonTheme.orange;
      case RewardKind.gravity:
        return NeonTheme.cyan;
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
      case RewardKind.color:
        return 'bp_color'.tr;
      case RewardKind.joker:
        return 'bp_joker'.tr;
      case RewardKind.lightning:
        return 'bp_lightning'.tr;
      case RewardKind.royal:
        return 'bp_royal'.tr;
      case RewardKind.gravity:
        return 'bp_gravity'.tr;
    }
  }
}
