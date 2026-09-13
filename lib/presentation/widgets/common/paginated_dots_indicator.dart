import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// N dots for a paginated carousel/onboarding flow — the dot at
/// [currentIndex] renders bigger/brighter than the rest. Pure presentation:
/// does not own a `PageController` itself, the caller wires it up via
/// `PageView.onPageChanged` and passes the resulting index in.
class PaginatedDotsIndicator extends StatelessWidget {
  const PaginatedDotsIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.color,
    this.dotSize = 8,
    this.activeDotSize = 12,
    this.spacing = 8,
    this.semanticLabel,
  }) : assert(count > 0, 'count must be positive');

  final int count;
  final int currentIndex;
  final Color? color;
  final double dotSize;
  final double activeDotSize;
  final double spacing;

  /// Overrides the default "Page N of M" Semantics label (ENH-37).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? NeonTheme.purple;
    return Semantics(
      label: semanticLabel ?? 'Page ${currentIndex + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              // ENH-38: EdgeInsetsDirectional's "end" is physical right in
              // LTR, physical left in RTL — Row already reverses child
              // paint order under RTL, so the gap needs to trail each dot
              // in READING order (not always physical-right) to land in
              // the same visual spot between dots either way.
              padding: EdgeInsetsDirectional.only(
                end: i == count - 1 ? 0 : spacing,
              ),
              child: AnimatedContainer(
                duration: NeonTheme.reducedMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: i == currentIndex ? activeDotSize : dotSize,
                height: i == currentIndex ? activeDotSize : dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == currentIndex ? c : c.withValues(alpha: 0.35),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
