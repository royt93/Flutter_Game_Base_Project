import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Thanh tiến trình dạng pill bo tròn, có 1-3 mốc sao dọc theo track — mốc nào
/// đã bị fill vượt qua thì sáng lên (filled), ngược lại là outline mờ. Dùng
/// cho world progress / event track kiểu "đạt 33%/66%/100% mở sao".
class ProgressBarStars extends StatelessWidget {
  const ProgressBarStars({
    super.key,
    required this.progress,
    this.starThresholds = const [0.33, 0.66, 1.0],
    this.height = 20,
    this.fillColor,
    this.trackColor,
  });

  /// 0.0-1.0.
  final double progress;

  /// Mốc sao (0.0-1.0), tối đa dùng thực tế 1-3 mốc.
  final List<double> starThresholds;
  final double height;
  final Color? fillColor;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final fill = fillColor ?? NeonTheme.lime;
    final track = trackColor ?? NeonTheme.cardAlt;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: height + 10,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomLeft,
            children: [
              Container(
                width: w,
                height: height,
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(height),
                  border: Border.all(color: NeonTheme.muted, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: p),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (context, t, _) => FractionallySizedBox(
                      widthFactor: t,
                      child: Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(height),
                          boxShadow: NeonTheme.glow(fill, blur: 10, spread: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (final t in starThresholds)
                Positioned(
                  left: (w * t.clamp(0.0, 1.0) - 12).clamp(0.0, w - 24),
                  bottom: height - 6,
                  child: Icon(
                    p >= t ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 24,
                    color: p >= t ? NeonTheme.gold : NeonTheme.muted,
                    shadows: p >= t
                        ? [Shadow(color: NeonTheme.gold, blurRadius: 8)]
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
