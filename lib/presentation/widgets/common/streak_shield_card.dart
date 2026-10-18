import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'common_button.dart';
import '../neon_dialog.dart';

/// Presentation-only card showing streak protection status, available freeze
/// shields, and action buttons to use a shield or repair streak (FEAT-144).
///
/// Composes with [DailyLoginService] and [StreakRepairDialog] at the caller
/// level; does not touch storage or inventory directly.
class StreakShieldCard extends StatelessWidget {
  StreakShieldCard({
    super.key,
    required this.streakDays,
    required this.shieldCount,
    this.missedDateLabel = 'Yesterday',
    this.onUseShield,
    this.onRepair,
    this.onDismiss,
    this.title = 'Streak Protected!',
    this.message,
    this.useShieldLabel = 'Use Shield',
    this.repairLabel = 'Repair Streak',
    this.dismissLabel = 'Dismiss',
    this.semanticLabel,
    this.showActions = true,
  }) {
    if (streakDays < 0) {
      throw ArgumentError.value(
        streakDays,
        'streakDays',
        'must be non-negative',
      );
    }
    if (shieldCount < 0) {
      throw ArgumentError.value(
        shieldCount,
        'shieldCount',
        'must be non-negative',
      );
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (useShieldLabel.trim().isEmpty) {
      throw ArgumentError.value(
        useShieldLabel,
        'useShieldLabel',
        'must not be empty',
      );
    }
    if (repairLabel.trim().isEmpty) {
      throw ArgumentError.value(
        repairLabel,
        'repairLabel',
        'must not be empty',
      );
    }
    if (dismissLabel.trim().isEmpty) {
      throw ArgumentError.value(
        dismissLabel,
        'dismissLabel',
        'must not be empty',
      );
    }
  }

  final int streakDays;
  final int shieldCount;
  final String missedDateLabel;
  final VoidCallback? onUseShield;
  final VoidCallback? onRepair;
  final VoidCallback? onDismiss;
  final String title;
  final String? message;
  final String useShieldLabel;
  final String repairLabel;
  final String dismissLabel;
  final String? semanticLabel;
  final bool showActions;

  bool get hasShield => shieldCount > 0;

  /// Shows the card inside a [NeonDialog.show] in-tree overlay.
  static Future<void> show(
    BuildContext context, {
    required int streakDays,
    required int shieldCount,
    String missedDateLabel = 'Yesterday',
    VoidCallback? onUseShield,
    VoidCallback? onRepair,
    VoidCallback? onDismiss,
    String title = 'Streak Protection',
    String? message,
    String useShieldLabel = 'Use Shield',
    String repairLabel = 'Repair Streak',
    String dismissLabel = 'Dismiss',
    String? semanticLabel,
  }) {
    final hasShield = shieldCount > 0;
    return NeonDialog.show<void>(
      context: context,
      title: title,
      color: hasShield ? NeonTheme.cyan : NeonTheme.orange,
      icon: hasShield ? Icons.shield_rounded : Icons.shield_outlined,
      content: StreakShieldCard(
        streakDays: streakDays,
        shieldCount: shieldCount,
        missedDateLabel: missedDateLabel,
        onUseShield: onUseShield,
        onRepair: onRepair,
        onDismiss: onDismiss,
        title: title,
        message: message,
        useShieldLabel: useShieldLabel,
        repairLabel: repairLabel,
        dismissLabel: dismissLabel,
        semanticLabel: semanticLabel,
        showActions: false,
      ),
      actions: [
        if (onDismiss != null)
          NeonDialogAction(
            label: dismissLabel,
            color: NeonTheme.muted,
            onTap: onDismiss,
          ),
        if (hasShield && onUseShield != null)
          NeonDialogAction(
            label: useShieldLabel,
            color: NeonTheme.cyan,
            onTap: onUseShield,
          )
        else if (onRepair != null)
          NeonDialogAction(
            label: repairLabel,
            color: NeonTheme.orange,
            onTap: onRepair,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultMsg = hasShield
        ? 'You missed login $missedDateLabel! Use a Freeze Shield to save your $streakDays-day streak.'
        : 'You missed login $missedDateLabel and have 0 Freeze Shields left!';
    final effectiveMessage = message ?? defaultMsg;

    final effectiveSemantics =
        semanticLabel ??
        '$title. $streakDays day streak. $shieldCount freeze shields available. $effectiveMessage';

    return Semantics(
      key: const ValueKey('streakShieldCardSemantics'),
      container: true,
      label: effectiveSemantics,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            effectiveMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: NeonTheme.inkSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: NeonTheme.s16),
          // Shield and streak status panel
          RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.all(NeonTheme.s16),
              decoration: BoxDecoration(
                color: NeonTheme.cardAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasShield
                      ? NeonTheme.cyan.withValues(alpha: 0.4)
                      : NeonTheme.orange.withValues(alpha: 0.4),
                  width: 2,
                ),
                boxShadow: NeonTheme.glow(
                  hasShield ? NeonTheme.cyan : NeonTheme.orange,
                  blur: 12,
                  intensity: 0.25,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMetric(
                    label: 'Current Streak',
                    value: '$streakDays days',
                    icon: Icons.local_fire_department_rounded,
                    color: NeonTheme.orange,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: NeonTheme.inkSoft.withValues(alpha: 0.2),
                  ),
                  _buildMetric(
                    label: 'Freeze Shields',
                    value: '$shieldCount left',
                    icon: hasShield
                        ? Icons.shield_rounded
                        : Icons.shield_outlined,
                    color: hasShield ? NeonTheme.cyan : NeonTheme.red,
                  ),
                ],
              ),
            ),
          ),
          if (showActions) ...[
            const SizedBox(height: NeonTheme.s16),
            if (hasShield && onUseShield != null) ...[
              CommonButton(
                key: const ValueKey('streakShieldUseBtn'),
                label: useShieldLabel,
                color: NeonTheme.cyan,
                onTap: onUseShield,
              ),
            ] else if (onRepair != null) ...[
              CommonButton(
                key: const ValueKey('streakShieldRepairBtn'),
                label: repairLabel,
                color: NeonTheme.orange,
                onTap: onRepair,
              ),
            ],
            if (onDismiss != null) ...[
              const SizedBox(height: NeonTheme.s8),
              CommonButton(
                key: const ValueKey('streakShieldDismissBtn'),
                label: dismissLabel,
                variant: CommonButtonVariant.secondary,
                color: NeonTheme.muted,
                onTap: onDismiss,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: NeonTheme.inkSoft,
          ),
        ),
      ],
    );
  }
}
