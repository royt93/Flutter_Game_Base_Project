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
  }) : assert(count > 0, 'count must be positive');

  final int count;
  final int currentIndex;
  final Color? color;
  final double dotSize;
  final double activeDotSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final c = color ?? NeonTheme.purple;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(right: i == count - 1 ? 0 : spacing),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
    );
  }
}
