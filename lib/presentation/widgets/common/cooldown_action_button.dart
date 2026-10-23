import 'package:flutter/material.dart';

import 'common_button.dart';
import 'cooldown_countdown_chip.dart';

/// Button gated by a caller-read cooldown. While [remaining] is positive the
/// button is disabled and a countdown chip is shown; when the chip reaches
/// zero [onReady] fires so the caller re-reads the service and passes
/// `Duration.zero`. The caller still re-checks the service inside [onTap]:
/// this gate is UI only, not an anti-cheat boundary.
class CooldownActionButton extends StatelessWidget {
  CooldownActionButton({
    super.key,
    required this.label,
    required this.remaining,
    required this.onTap,
    this.onReady,
    this.busy = false,
    this.waitingSemanticLabel,
  }) {
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank');
    }
    if (remaining < Duration.zero) {
      throw ArgumentError.value(remaining, 'remaining', 'must be >= 0');
    }
  }

  final String label;
  final Duration remaining;
  final VoidCallback onTap;
  final VoidCallback? onReady;
  final bool busy;
  final String? waitingSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final waiting = remaining > Duration.zero;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CommonButton(
            key: const ValueKey('cooldownActionButton'),
            label: label,
            width: double.infinity,
            onTap: waiting || busy ? null : onTap,
          ),
          if (waiting)
            Center(
              child: CooldownCountdownChip(
                key: const ValueKey('cooldownActionChip'),
                remaining: remaining,
                onDone: onReady,
                semanticLabel: waitingSemanticLabel,
              ),
            ),
        ],
      ),
    );
  }
}
