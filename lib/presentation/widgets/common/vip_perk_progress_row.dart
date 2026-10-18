import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';
import 'common_button.dart';

/// Single loyalty/VIP benefit (presentation-only).
@immutable
class VipPerk {
  const VipPerk({
    required this.icon,
    required this.label,
    this.isUnlocked = true,
  });

  final IconData icon;
  final String label;
  final bool isUnlocked;
}

/// Presentation-only card/row displaying current VIP tier, point progress
/// toward the next tier, and unlocked perks (FEAT-145).
///
/// Composes directly with caller-owned VIP/loyalty services without embedding
/// store or IAP dependencies.
class VipPerkProgressRow extends StatelessWidget {
  VipPerkProgressRow({
    super.key,
    required this.currentTier,
    required this.currentPoints,
    this.nextTierPoints,
    this.tierLabel,
    this.perks = const [],
    this.onAction,
    this.actionLabel = 'View Perks',
    this.semanticLabel,
  }) {
    if (currentTier < 0) {
      throw ArgumentError.value(
        currentTier,
        'currentTier',
        'must be non-negative',
      );
    }
    if (currentPoints < 0) {
      throw ArgumentError.value(
        currentPoints,
        'currentPoints',
        'must be non-negative',
      );
    }
    if (nextTierPoints != null && nextTierPoints! <= 0) {
      throw ArgumentError.value(
        nextTierPoints,
        'nextTierPoints',
        'must be positive when provided',
      );
    }
    if (tierLabel != null && tierLabel!.trim().isEmpty) {
      throw ArgumentError.value(tierLabel, 'tierLabel', 'must not be empty');
    }
    if (actionLabel.trim().isEmpty) {
      throw ArgumentError.value(
        actionLabel,
        'actionLabel',
        'must not be empty',
      );
    }
  }

  final int currentTier;
  final int currentPoints;
  final int? nextTierPoints;
  final String? tierLabel;
  final List<VipPerk> perks;
  final VoidCallback? onAction;
  final String actionLabel;
  final String? semanticLabel;

  bool get isMaxTier => nextTierPoints == null;

  double get progressFraction {
    if (isMaxTier) return 1.0;
    if (nextTierPoints == 0) return 0.0;
    return (currentPoints / nextTierPoints!).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTierLabel = tierLabel ?? 'VIP $currentTier';
    final progressText = isMaxTier
        ? '${fmtNum(currentPoints)} pts (MAX)'
        : '${fmtNum(currentPoints)} / ${fmtNum(nextTierPoints!)} pts';

    final effectiveSemantics =
        semanticLabel ??
        '$effectiveTierLabel. Progress: $progressText. ${perks.length} perks available.';

    final reduced = NeonTheme.reducedMotion(context);

    return Semantics(
      key: const ValueKey('vipPerkProgressRowSemantics'),
      container: true,
      label: effectiveSemantics,
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: NeonTheme.gold.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            ...NeonTheme.glow(NeonTheme.gold, blur: 14, intensity: 0.2),
            ...NeonTheme.drop(y: 4, blur: 12),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Tier badge & Action button
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [NeonTheme.gold, NeonTheme.orange],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: NeonTheme.glow(NeonTheme.gold, blur: 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            effectiveTierLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onAction != null)
                  CommonButton(
                    key: const ValueKey('vipPerkActionBtn'),
                    label: actionLabel,
                    width: 110,
                    variant: CommonButtonVariant.secondary,
                    color: NeonTheme.purple,
                    onTap: onAction,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 4,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    isMaxTier ? 'Maximum Tier Reached' : 'Next Tier Progress',
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: NeonTheme.inkSoft,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    progressText,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: NeonTheme.gold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 12,
                  color: NeonTheme.cardAlt,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progressFraction),
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [NeonTheme.gold, NeonTheme.purple],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (perks.isNotEmpty) ...[
              const SizedBox(height: NeonTheme.s16),
              Text(
                'Perks & Privileges',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: NeonTheme.inkSoft,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: NeonTheme.s8,
                runSpacing: 6,
                children: perks.map(_buildPerkChip).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerkChip(VipPerk perk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: perk.isUnlocked
            ? NeonTheme.purple.withValues(alpha: 0.12)
            : NeonTheme.cardAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: perk.isUnlocked
              ? NeonTheme.purple.withValues(alpha: 0.4)
              : NeonTheme.inkSoft.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            perk.icon,
            size: 14,
            color: perk.isUnlocked ? NeonTheme.purple : NeonTheme.inkSoft,
          ),
          const SizedBox(width: 4),
          Text(
            perk.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: perk.isUnlocked ? NeonTheme.ink : NeonTheme.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
