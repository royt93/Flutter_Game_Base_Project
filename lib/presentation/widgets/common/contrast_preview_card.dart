import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Reusable contrast preview for one caller-supplied foreground/background pair.
/// It does not change [NeonTheme], save colors or run a global audit.
class ContrastPreviewCard extends StatelessWidget {
  ContrastPreviewCard({
    super.key,
    required this.foreground,
    required this.background,
    required this.sampleText,
    this.threshold,
    this.largeText = false,
    this.onTap,
    this.semanticLabel,
    this.passLabel = 'Pass',
    this.failLabel = 'Needs more contrast',
  }) {
    if (sampleText.trim().isEmpty) {
      throw ArgumentError.value(sampleText, 'sampleText', 'must not be blank');
    }
    final requestedThreshold = threshold;
    if (requestedThreshold != null &&
        (!requestedThreshold.isFinite || requestedThreshold <= 0)) {
      throw ArgumentError.value(
        threshold,
        'threshold',
        'must be finite and > 0',
      );
    }
    for (final (name, value) in [
      ('semanticLabel', semanticLabel),
      ('passLabel', passLabel),
      ('failLabel', failLabel),
    ]) {
      if (value != null && value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
  }

  final Color foreground;
  final Color background;
  final String sampleText;

  /// WCAG contrast threshold. Defaults to AA normal text 4.5:1.
  final double? threshold;

  /// Large text defaults to the WCAG AA large-text threshold of 3:1.
  final bool largeText;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String passLabel;
  final String failLabel;

  double get contrastRatio {
    final first = foreground.computeLuminance();
    final second = background.computeLuminance();
    final lighter = first > second ? first : second;
    final darker = first > second ? second : first;
    return (lighter + 0.05) / (darker + 0.05);
  }

  double get effectiveThreshold => threshold ?? (largeText ? 3.0 : 4.5);

  bool get passes => contrastRatio >= effectiveThreshold;

  @override
  Widget build(BuildContext context) {
    final ratio = contrastRatio;
    final pass = passes;
    final status = pass ? passLabel : failLabel;
    final ratioText = '${ratio.toStringAsFixed(2)}:1';
    final spoken =
        semanticLabel ??
        '$status, contrast $ratioText, threshold '
            '${effectiveThreshold.toStringAsFixed(1)} to 1, sample $sampleText';
    final color = pass ? NeonTheme.lime : NeonTheme.red;

    final card = Container(
      constraints: BoxConstraints(minHeight: onTap == null ? 0 : 48),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  pass ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ratioText,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: foreground.withValues(alpha: 0.45)),
              ),
              child: Text(
                sampleText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: largeText ? 20 : 14,
                  fontWeight: largeText ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Threshold ${effectiveThreshold.toStringAsFixed(1)}:1',
              style: TextStyle(
                color: foreground.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) {
      return Semantics(label: spoken, excludeSemantics: true, child: card);
    }
    return Semantics(
      button: true,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('contrastPreviewTap'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: card,
      ),
    );
  }
}
