import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';

/// One caller-formatted before/after stat preview.
@immutable
class UpgradeStatChange {
  const UpgradeStatChange({
    required this.label,
    required this.currentValue,
    required this.nextValue,
    this.icon,
    this.isImprovement = true,
  });

  final String label;
  final String currentValue;
  final String nextValue;
  final IconData? icon;
  final bool isImprovement;
}

/// One caller-formatted upgrade cost row.
@immutable
class UpgradeCost {
  const UpgradeCost({
    required this.label,
    required this.currentAmount,
    required this.requiredAmount,
    this.icon = Icons.monetization_on_rounded,
  });

  final String label;
  final int currentAmount;
  final int requiredAmount;
  final IconData icon;

  bool get isAffordable => currentAmount >= requiredAmount;
}

/// Presentation-only upgrade preview comparing supplied stats/costs.
///
/// Caller computes new stats, affordability, consumes currency and commits the
/// upgrade. This panel only routes [onUpgrade].
class UpgradePreviewPanel extends StatelessWidget {
  UpgradePreviewPanel({
    super.key,
    required this.title,
    required this.currentLevel,
    required this.nextLevel,
    required this.statChanges,
    required this.costs,
    required this.onUpgrade,
    this.isMaxLevel = false,
    this.isUpgrading = false,
    this.upgradeLabel = 'Upgrade',
    this.maxLevelLabel = 'MAX LEVEL',
    this.subtitle,
    this.semanticLabel,
  }) {
    if (title.trim().isEmpty ||
        upgradeLabel.trim().isEmpty ||
        maxLevelLabel.trim().isEmpty) {
      throw ArgumentError('title and button labels must not be empty');
    }
    if (currentLevel < 0 || nextLevel <= currentLevel) {
      throw ArgumentError(
        'currentLevel must be non-negative and nextLevel higher',
      );
    }
    if (statChanges.isEmpty) {
      throw ArgumentError.value(
        statChanges,
        'statChanges',
        'must not be empty',
      );
    }
    if (costs.isEmpty && !isMaxLevel) {
      throw ArgumentError.value(
        costs,
        'costs',
        'must not be empty unless max level',
      );
    }
    for (final stat in statChanges) {
      if (stat.label.trim().isEmpty ||
          stat.currentValue.trim().isEmpty ||
          stat.nextValue.trim().isEmpty) {
        throw ArgumentError.value(
          stat,
          'statChanges',
          'labels and values must not be empty',
        );
      }
    }
    for (final cost in costs) {
      if (cost.label.trim().isEmpty ||
          cost.currentAmount < 0 ||
          cost.requiredAmount < 0) {
        throw ArgumentError.value(
          cost,
          'costs',
          'label must be non-empty and amounts non-negative',
        );
      }
    }
  }

  final String title;
  final int currentLevel;
  final int nextLevel;
  final List<UpgradeStatChange> statChanges;
  final List<UpgradeCost> costs;
  final VoidCallback onUpgrade;
  final bool isMaxLevel;
  final bool isUpgrading;
  final String upgradeLabel;
  final String maxLevelLabel;
  final String? subtitle;
  final String? semanticLabel;

  bool get isAffordable => costs.every((cost) => cost.isAffordable);
  bool get _canUpgrade => !isMaxLevel && !isUpgrading && isAffordable;

  @override
  Widget build(BuildContext context) {
    final status = isMaxLevel
        ? maxLevelLabel
        : isUpgrading
        ? 'Upgrading…'
        : !isAffordable
        ? 'Insufficient resources'
        : null;
    final semantics =
        semanticLabel ??
        '$title. Level $currentLevel to $nextLevel. ${statChanges.map((s) => '${s.label} ${s.currentValue} to ${s.nextValue}').join('. ')}. ${isAffordable ? "Affordable" : "Insufficient resources"}.';

    return Semantics(
      key: const ValueKey('upgradePreviewSemantics'),
      container: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: NeonTheme.purple.withValues(alpha: 0.4),
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
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: NeonTheme.s8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: NeonTheme.s8,
              runSpacing: 4,
              children: [
                _levelBadge('LV $currentLevel', NeonTheme.inkSoft),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: NeonTheme.cyan,
                  size: 18,
                ),
                _levelBadge('LV $nextLevel', NeonTheme.purple),
              ],
            ),
            const SizedBox(height: NeonTheme.s8),
            for (final stat in statChanges) _statRow(stat),
            if (costs.isNotEmpty) ...[
              const SizedBox(height: NeonTheme.s8),
              Text(
                'Upgrade Cost',
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: NeonTheme.s8,
                runSpacing: 6,
                children: [for (final cost in costs) _costChip(cost)],
              ),
            ],
            if (status != null) ...[
              const SizedBox(height: NeonTheme.s8),
              Text(
                status,
                key: const ValueKey('upgradePreviewStatus'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isMaxLevel ? NeonTheme.gold : NeonTheme.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: NeonTheme.s16),
            CommonButton(
              key: const ValueKey('upgradePreviewButton'),
              label: isMaxLevel ? maxLevelLabel : upgradeLabel,
              color: NeonTheme.purple,
              loading: isUpgrading,
              onTap: _canUpgrade ? onUpgrade : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
    ),
  );

  Widget _statRow(UpgradeStatChange stat) {
    final color = stat.isImprovement ? NeonTheme.lime : NeonTheme.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (stat.icon != null) ...[
            Icon(stat.icon, size: 17, color: NeonTheme.cyan),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              stat.label,
              style: TextStyle(
                color: NeonTheme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              stat.currentValue,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Icon(Icons.arrow_forward_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              stat.nextValue,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _costChip(UpgradeCost cost) {
    final color = cost.isAffordable ? NeonTheme.gold : NeonTheme.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Icon(cost.icon, size: 15, color: color),
          Text(
            '${cost.currentAmount}/${cost.requiredAmount} ${cost.label}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
