import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'milestone_celebration_dialog.dart' show MilestoneReward;

/// Caller-provided progress for one long-term achievement milestone.
@immutable
class AchievementRoadmapItem {
  const AchievementRoadmapItem({
    required this.id,
    required this.title,
    required this.progress,
    required this.target,
    required this.reward,
    this.description,
    this.isClaimed = false,
  });

  final String id;
  final String title;
  final String? description;
  final int progress;
  final int target;
  final MilestoneReward reward;
  final bool isClaimed;

  bool get isComplete => progress >= target;
  bool get isClaimable => isComplete && !isClaimed;
}

/// Long-term achievement roadmap with caller-owned progress and reward claims.
class AchievementRoadmapCard extends StatelessWidget {
  AchievementRoadmapCard({
    super.key,
    required this.items,
    required this.onClaim,
    this.onOpen,
    this.title = 'Achievement Roadmap',
    this.emptyMessage = 'No achievements yet.',
    this.isLoading = false,
    this.semanticLabel,
    this.maxVisibleItems = 4,
  }) {
    if (title.trim().isEmpty || emptyMessage.trim().isEmpty) {
      throw ArgumentError('title and emptyMessage must not be empty');
    }
    if (maxVisibleItems <= 0) {
      throw ArgumentError.value(
        maxVisibleItems,
        'maxVisibleItems',
        'must be positive',
      );
    }
    final ids = <String>{};
    for (final item in items) {
      if (item.id.trim().isEmpty || item.title.trim().isEmpty) {
        throw ArgumentError.value(
          item,
          'items',
          'id and title must not be empty',
        );
      }
      if (!ids.add(item.id)) {
        throw ArgumentError.value(item.id, 'items', 'duplicate achievement id');
      }
      if (item.progress < 0 || item.target <= 0) {
        throw ArgumentError.value(
          item,
          'items',
          'progress must be non-negative and target positive',
        );
      }
      if (item.reward.label.trim().isEmpty) {
        throw ArgumentError.value(
          item.reward.label,
          'items',
          'reward label must not be empty',
        );
      }
    }
  }

  final List<AchievementRoadmapItem> items;
  final ValueChanged<String> onClaim;
  final ValueChanged<String>? onOpen;
  final String title;
  final String emptyMessage;
  final bool isLoading;
  final String? semanticLabel;
  final int maxVisibleItems;

  @override
  Widget build(BuildContext context) {
    final semantics = semanticLabel ?? '$title. ${items.length} achievements.';
    final listHeight = maxVisibleItems * 112.0;
    return Semantics(
      key: const ValueKey('achievementRoadmapSemantics'),
      container: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: NeonTheme.gold.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: NeonTheme.drop(y: 4, blur: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: NeonTheme.s8),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(NeonTheme.s16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: NeonTheme.s16),
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NeonTheme.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              SizedBox(
                height: listHeight,
                child: ListView.builder(
                  key: const ValueKey('achievementRoadmapList'),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _RoadmapItem(
                    item: items[index],
                    onClaim: () => onClaim(items[index].id),
                    onOpen: onOpen == null
                        ? null
                        : () => onOpen!(items[index].id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapItem extends StatelessWidget {
  const _RoadmapItem({required this.item, required this.onClaim, this.onOpen});

  final AchievementRoadmapItem item;
  final VoidCallback onClaim;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final complete = item.isComplete;
    final claimed = item.isClaimed;
    final color = claimed
        ? NeonTheme.lime
        : complete
        ? NeonTheme.gold
        : NeonTheme.cyan;
    final progress = (item.progress / item.target).clamp(0.0, 1.0);
    final rewardText = item.reward.amountLabel == null
        ? item.reward.label
        : '${item.reward.label} ${item.reward.amountLabel}';

    return Semantics(
      key: ValueKey('achievementRoadmapItem_${item.id}'),
      container: true,
      label:
          '${item.title}. ${item.progress} of ${item.target}. ${claimed
              ? "Claimed"
              : complete
              ? "Reward available"
              : "In progress"}. Reward: $rewardText.',
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: NeonTheme.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NeonTheme.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    claimed
                        ? 'Claimed'
                        : complete
                        ? 'Complete'
                        : '${item.progress}/${item.target}',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (item.description != null)
                Text(
                  item.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: NeonTheme.inkSoft, fontSize: 10),
                ),
              const SizedBox(height: 4),
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    color: color,
                    backgroundColor: NeonTheme.card,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    'Reward: $rewardText',
                    style: TextStyle(
                      color: NeonTheme.inkSoft,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.isClaimable)
                    GestureDetector(
                      key: ValueKey('achievementClaim_${item.id}'),
                      onTap: onClaim,
                      child: Text(
                        'Claim',
                        style: TextStyle(
                          color: NeonTheme.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
