import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';
import 'common_button.dart';
import 'panel_card.dart';

/// Presentation-only prestige progress: balance toward the threshold, the
/// permanent multiplier and a CTA enabled only when ready. It never performs
/// a prestige; [onPrestige] should open a confirmation (for example
/// `PrestigeConfirmationCard.show`) before the caller invokes the service.
class PrestigeReadinessCard extends StatelessWidget {
  PrestigeReadinessCard({
    super.key,
    required this.current,
    required this.threshold,
    required this.multiplierText,
    required this.onPrestige,
    this.busy = false,
    this.title = 'Prestige',
    this.progressLabel = 'Progress',
    this.readyLabel = 'Prestige now',
    this.notReadyLabel = 'Keep earning to prestige',
  }) {
    if (threshold <= 0) {
      throw ArgumentError.value(threshold, 'threshold', 'must be > 0');
    }
    if (current < 0) {
      throw ArgumentError.value(current, 'current', 'must be >= 0');
    }
    for (final (name, value) in [
      ('multiplierText', multiplierText),
      ('title', title),
      ('progressLabel', progressLabel),
      ('readyLabel', readyLabel),
      ('notReadyLabel', notReadyLabel),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final int current;
  final int threshold;
  final String multiplierText;
  final VoidCallback onPrestige;
  final bool busy;
  final String title;
  final String progressLabel;
  final String readyLabel;
  final String notReadyLabel;

  bool get ready => current >= threshold;

  @override
  Widget build(BuildContext context) {
    final fraction = (current / threshold).clamp(0.0, 1.0);
    final counts = '${fmtNum(current)} / ${fmtNum(threshold)}';
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: PanelCard(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(color: NeonTheme.ink, fontSize: 18)),
              Text(multiplierText),
              const SizedBox(height: 8),
              Semantics(
                label: progressLabel,
                value: counts,
                child: ExcludeSemantics(
                  child: LinearProgressIndicator(value: fraction),
                ),
              ),
              Text(counts),
              const SizedBox(height: 8),
              CommonButton(
                key: const ValueKey('prestigeReadinessAction'),
                label: ready ? readyLabel : notReadyLabel,
                variant: CommonButtonVariant.primary,
                width: double.infinity,
                onTap: ready && !busy ? onPrestige : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
