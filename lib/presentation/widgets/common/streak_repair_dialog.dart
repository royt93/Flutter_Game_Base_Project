import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';
import 'common_button.dart';

class StreakRepairDialog extends StatefulWidget {
  StreakRepairDialog({
    super.key,
    required this.streakDays,
    required this.onRepair,
    required this.onSkip,
    this.costGems = 20,
    this.title = 'Streak Lost!',
    this.subtitle,
    this.repairLabel,
    this.skipLabel,
  }) {
    if (streakDays < 1) {
      throw ArgumentError.value(streakDays, 'streakDays', 'must be at least 1');
    }
    if (costGems != null && costGems! < 0) {
      throw ArgumentError.value(costGems, 'costGems', 'must be non-negative');
    }
  }

  final int streakDays;
  final VoidCallback onRepair;
  final VoidCallback onSkip;
  final int? costGems;
  final String title;
  final String? subtitle;
  final String? repairLabel;
  final String? skipLabel;

  static Future<void> show(
    BuildContext context, {
    required int streakDays,
    required VoidCallback onRepair,
    required VoidCallback onSkip,
    int? costGems = 20,
    String title = 'Streak Lost!',
    String? subtitle,
    String? repairLabel,
    String? skipLabel,
  }) {
    return NeonDialog.show<void>(
      context: context,
      title: title,
      message:
          subtitle ??
          'Your $streakDays-day streak is broken! Repair it now to keep your rewards multiplier.',
      color: NeonTheme.orange,
      icon: Icons.local_fire_department_rounded,
      actions: [
        NeonDialogAction(
          label: skipLabel ?? 'Start Over',
          color: NeonTheme.muted,
          onTap: onSkip,
        ),
        NeonDialogAction(
          label:
              repairLabel ??
              (costGems != null ? 'Repair ($costGems gems)' : 'Repair Streak'),
          color: NeonTheme.orange,
          onTap: onRepair,
        ),
      ],
    );
  }

  @override
  State<StreakRepairDialog> createState() => _StreakRepairDialogState();
}

class _StreakRepairDialogState extends State<StreakRepairDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final CurvedAnimation _pulse = CurvedAnimation(
    parent: _pulseController,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _pulseController.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NeonTheme.reducedMotion(context) && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = NeonTheme.reducedMotion(context);
    final repairText =
        widget.repairLabel ??
        (widget.costGems != null
            ? 'Repair (${widget.costGems} gems)'
            : 'Repair Streak');
    final skipText = widget.skipLabel ?? 'Start Over';

    return Semantics(
      container: true,
      label:
          '${widget.title}. Streak of ${widget.streakDays} days lost. $repairText or $skipText.',
      child: Center(
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: NeonTheme.s24),
          padding: const EdgeInsets.all(NeonTheme.s24),
          decoration: BoxDecoration(
            color: NeonTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: NeonTheme.cyan.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: NeonTheme.glow(NeonTheme.cyan, blur: 16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final scale = reduced ? 1.0 : 0.95 + 0.1 * _pulse.value;
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NeonTheme.cardAlt,
                    border: Border.all(color: NeonTheme.orange, width: 3),
                    boxShadow: NeonTheme.glow(NeonTheme.orange, blur: 14),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.ac_unit_rounded,
                        color: NeonTheme.cyan.withValues(alpha: 0.8),
                        size: 56,
                      ),
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: NeonTheme.orange,
                        size: 40,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NeonTheme.s16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: NeonTheme.s8),
              Text(
                widget.subtitle ??
                    'Your ${widget.streakDays}-day streak is frozen! Repair it to continue where you left off.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: NeonTheme.s24),
              CommonButton(
                key: const ValueKey('streakRepairConfirm'),
                label: repairText,
                color: NeonTheme.orange,
                width: double.infinity,
                onTap: widget.onRepair,
              ),
              const SizedBox(height: NeonTheme.s8),
              CommonButton(
                key: const ValueKey('streakRepairSkip'),
                label: skipText,
                variant: CommonButtonVariant.secondary,
                width: double.infinity,
                onTap: widget.onSkip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
