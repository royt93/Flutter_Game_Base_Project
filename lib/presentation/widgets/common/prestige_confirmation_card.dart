import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import '../neon_dialog.dart';

/// One reward earned on prestige (presentation-only).
@immutable
class PrestigeReward {
  const PrestigeReward({
    required this.icon,
    required this.label,
    required this.amount,
  });

  final IconData icon;
  final String label;
  final String amount;
}

/// Confirmation card shown before prestiging (resetting short-term progress
/// for permanent multiplier boosts and rewards).
///
/// Presentation-only: caller handles the actual reset transaction.
class PrestigeConfirmationCard extends StatelessWidget {
  PrestigeConfirmationCard({
    super.key,
    required this.currentLevel,
    required this.requiredPrestigeValue,
    required this.currentMultiplier,
    required this.nextMultiplier,
    required this.rewards,
    required this.onConfirm,
    required this.onCancel,
    this.title = 'Prestige Confirmation',
    this.message = 'Reset your current level to unlock permanent boosts!',
    this.confirmLabel = 'Prestige Now',
    this.cancelLabel = 'Keep Playing',
    this.semanticLabel,
    this.showActions = true,
  }) {
    if (currentLevel < 0) {
      throw ArgumentError.value(
        currentLevel,
        'currentLevel',
        'must be non-negative',
      );
    }
    if (requiredPrestigeValue.trim().isEmpty) {
      throw ArgumentError.value(
        requiredPrestigeValue,
        'requiredPrestigeValue',
        'must not be empty',
      );
    }
    if (!currentMultiplier.isFinite || currentMultiplier <= 0) {
      throw ArgumentError.value(
        currentMultiplier,
        'currentMultiplier',
        'must be finite and positive',
      );
    }
    if (!nextMultiplier.isFinite || nextMultiplier <= currentMultiplier) {
      throw ArgumentError.value(
        nextMultiplier,
        'nextMultiplier',
        'must be finite and exceed currentMultiplier',
      );
    }
    if (rewards.isEmpty) {
      throw ArgumentError.value(rewards, 'rewards', 'must not be empty');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (confirmLabel.trim().isEmpty) {
      throw ArgumentError.value(
        confirmLabel,
        'confirmLabel',
        'must not be empty',
      );
    }
    if (cancelLabel.trim().isEmpty) {
      throw ArgumentError.value(
        cancelLabel,
        'cancelLabel',
        'must not be empty',
      );
    }
  }

  final int currentLevel;
  final String requiredPrestigeValue;
  final double currentMultiplier;
  final double nextMultiplier;
  final List<PrestigeReward> rewards;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final String? semanticLabel;
  final bool showActions;

  /// Shows the card inside a [NeonDialog.show] in-tree overlay.
  static Future<void> show(
    BuildContext context, {
    required int currentLevel,
    required String requiredPrestigeValue,
    required double currentMultiplier,
    required double nextMultiplier,
    required List<PrestigeReward> rewards,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
    String title = 'Prestige Confirmation',
    String message = 'Reset your current level to unlock permanent boosts!',
    String confirmLabel = 'Prestige Now',
    String cancelLabel = 'Keep Playing',
    String? semanticLabel,
  }) {
    if (currentLevel < 0) {
      throw ArgumentError.value(
        currentLevel,
        'currentLevel',
        'must be non-negative',
      );
    }
    if (requiredPrestigeValue.trim().isEmpty) {
      throw ArgumentError.value(
        requiredPrestigeValue,
        'requiredPrestigeValue',
        'must not be empty',
      );
    }
    if (!currentMultiplier.isFinite || currentMultiplier <= 0) {
      throw ArgumentError.value(
        currentMultiplier,
        'currentMultiplier',
        'must be finite and positive',
      );
    }
    if (!nextMultiplier.isFinite || nextMultiplier <= currentMultiplier) {
      throw ArgumentError.value(
        nextMultiplier,
        'nextMultiplier',
        'must be finite and exceed currentMultiplier',
      );
    }
    if (rewards.isEmpty) {
      throw ArgumentError.value(rewards, 'rewards', 'must not be empty');
    }

    return NeonDialog.show<void>(
      context: context,
      title: title,
      color: NeonTheme.purple,
      content: PrestigeConfirmationCard(
        currentLevel: currentLevel,
        requiredPrestigeValue: requiredPrestigeValue,
        currentMultiplier: currentMultiplier,
        nextMultiplier: nextMultiplier,
        rewards: rewards,
        onConfirm: onConfirm,
        onCancel: onCancel,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        semanticLabel: semanticLabel,
        showActions: false,
      ),
      actions: [
        NeonDialogAction(
          label: cancelLabel,
          color: NeonTheme.muted,
          onTap: onCancel,
        ),
        NeonDialogAction(
          label: confirmLabel,
          color: NeonTheme.purple,
          onTap: onConfirm,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final multDiff = nextMultiplier - currentMultiplier;
    final diffLabel = '+${multDiff.toStringAsFixed(1)}x';

    final label =
        semanticLabel ??
        '$title. Requirement: $requiredPrestigeValue. Current Level $currentLevel will reset to 1. Multiplier increases from ${currentMultiplier.toStringAsFixed(1)}x to ${nextMultiplier.toStringAsFixed(1)}x ($diffLabel).';

    final body = Semantics(
      key: const ValueKey('prestigeConfirmationSemantics'),
      label: label,
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: NeonTheme.inkSoft,
            ),
          ),
          const SizedBox(height: NeonTheme.s16),
          // Multiplier comparison rail
          RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NeonTheme.s16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: NeonTheme.cardAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: NeonTheme.cyan.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMultiplierColumn(
                    label: 'Current',
                    value: '${currentMultiplier.toStringAsFixed(1)}x',
                    color: NeonTheme.inkSoft,
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: NeonTheme.cyan,
                    size: 24,
                  ),
                  _buildMultiplierColumn(
                    label: 'After Prestige',
                    value: '${nextMultiplier.toStringAsFixed(1)}x',
                    diff: diffLabel,
                    color: NeonTheme.gold,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: NeonTheme.s16),
          // Threshold requirement & Level reset chip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: NeonTheme.s8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: NeonTheme.s8),
                Flexible(
                  child: Text(
                    'Requires $requiredPrestigeValue · Level $currentLevel resets to 1',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NeonTheme.s16),
          // Rewards section header
          Text(
            'Permanent Rewards',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: NeonTheme.inkSoft,
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          // Rewards list
          ...rewards.map(_buildRewardRow),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.sizeOf(context).height * 0.42).clamp(
              160.0,
              240.0,
            ),
          ),
          child: SingleChildScrollView(child: body),
        ),
        if (showActions) ...[
          const SizedBox(height: NeonTheme.s16),
          CommonButton(
            key: const ValueKey('prestigeConfirmBtn'),
            label: confirmLabel,
            color: NeonTheme.purple,
            onTap: onConfirm,
          ),
          const SizedBox(height: NeonTheme.s8),
          CommonButton(
            key: const ValueKey('prestigeCancelBtn'),
            label: cancelLabel,
            variant: CommonButtonVariant.secondary,
            color: NeonTheme.muted,
            onTap: onCancel,
          ),
        ],
      ],
    );
  }

  Widget _buildMultiplierColumn({
    required String label,
    required String value,
    required Color color,
    String? diff,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: NeonTheme.inkSoft,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        if (diff != null) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diff,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRewardRow(PrestigeReward reward) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NeonTheme.s16,
          vertical: NeonTheme.s8,
        ),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: NeonTheme.magenta.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(reward.icon, size: 20, color: NeonTheme.magenta),
            const SizedBox(width: NeonTheme.s8),
            Expanded(
              child: Text(
                reward.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: NeonTheme.ink,
                ),
              ),
            ),
            Text(
              reward.amount,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: NeonTheme.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
