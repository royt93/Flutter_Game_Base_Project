import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/data/progression_tree.dart';
import 'package:neon_jewels/presentation/controllers/progression_tree_controller.dart';
import 'package:neon_jewels/presentation/widgets/neon_app_bar.dart';
import 'package:neon_jewels/presentation/widgets/neon_bg.dart';

/// Wave 20.3 — Màn Cây tiến trình (Progression Tree).
class ProgressionTreeScreen extends StatelessWidget {
  const ProgressionTreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ProgressionTreeController>();
    return Scaffold(
      backgroundColor: NeonTheme.bgDark,
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'pt_title'.tr),
              Expanded(
                child: Obx(() {
                  // H4 fix: đọc Rx để Obx rebuild khi node được mở khoá
                  ctrl.unlockedNodes.length;
                  final stars = ctrl.totalStars;
                  final gold = ctrl.goldMilestonesCount();
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: kPtNodes.length,
                    separatorBuilder: (context2, idx) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context2, i) {
                      final node = kPtNodes[i];
                      final unlocked = ctrl.isUnlocked(node.id);
                      final cost = node.starCost > 0
                          ? node.starCost
                          : node.goldCost;
                      final current = node.starCost > 0 ? stars : gold;
                      final progress = (current / cost).clamp(0.0, 1.0);
                      return _NodeCard(
                        node: node,
                        unlocked: unlocked,
                        progress: progress,
                        current: current,
                        cost: cost,
                        usesGold: node.goldCost > 0,
                      );
                    },
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

class _NodeCard extends StatelessWidget {
  final PtNode node;
  final bool unlocked;
  final double progress;
  final int current;
  final int cost;
  final bool usesGold;
  const _NodeCard({
    required this.node,
    required this.unlocked,
    required this.progress,
    required this.current,
    required this.cost,
    required this.usesGold,
  });

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? node.color : NeonTheme.panel;
    final textColor = unlocked ? Colors.white : Colors.white54;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? node.color.withValues(alpha: 0.8) : Colors.white12,
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: unlocked ? NeonTheme.glow(node.color, blur: 12) : null,
      ),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.stars_rounded : Icons.lock_outline_rounded,
            color: color,
            size: 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.titleKey.tr,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  node.descKey.tr,
                  style: TextStyle(color: textColor, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (!unlocked) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      color: node.color,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usesGold
                        ? 'pt_gold_cost'.tr
                              .replaceFirst('@n', current.toString())
                              .replaceFirst('@t', cost.toString())
                        : 'pt_star_cost'.tr
                              .replaceFirst('@n', current.toString())
                              .replaceFirst('@t', cost.toString()),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ] else ...[
                  Text(
                    'pt_unlocked'.tr,
                    style: TextStyle(
                      color: node.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (node.id == 'ascendant') ...[
                    const SizedBox(height: 4),
                    Text(
                      'pt_ascendant_bonus_hint'.tr,
                      style: TextStyle(
                        color: node.color.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
