import 'package:flutter/material.dart';

import '../../../core/haptics.dart';
import '../../../core/neon_theme.dart';
import '../../../core/storage_service.dart';

class CandySlider extends StatefulWidget {
  CandySlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.trackHeight = 12,
    this.thumbRadius = 14,
    this.enableHaptic = true,
  }) {
    if (!min.isFinite || !max.isFinite || min >= max || !(max - min).isFinite) {
      throw ArgumentError.value(
        min,
        'min',
        'requires a finite range with min < max',
      );
    }
    if (!value.isFinite || value < min || value > max) {
      throw ArgumentError.value(value, 'value', 'must be within [$min, $max]');
    }
    if (divisions != null && divisions! <= 0) {
      throw ArgumentError.value(divisions, 'divisions', 'must be positive');
    }
    if (!trackHeight.isFinite || trackHeight <= 0) {
      throw ArgumentError.value(
        trackHeight,
        'trackHeight',
        'must be finite and positive',
      );
    }
    if (!thumbRadius.isFinite || thumbRadius <= 0) {
      throw ArgumentError.value(
        thumbRadius,
        'thumbRadius',
        'must be finite and positive',
      );
    }
  }

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double trackHeight;
  final double thumbRadius;
  final bool enableHaptic;

  @override
  State<CandySlider> createState() => _CandySliderState();
}

class _CandySliderState extends State<CandySlider> {
  late double _lastValue = widget.value;

  @override
  void didUpdateWidget(covariant CandySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastValue = widget.value;
  }

  void _change(double value) {
    if (value == _lastValue) return;
    final crossing =
        widget.divisions != null || value == widget.min || value == widget.max;
    _lastValue = value;
    if (widget.enableHaptic && crossing && StorageService.maybe != null) {
      fireHaptic(HapticLevel.light);
    }
    widget.onChanged!(value);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeColor ?? NeonTheme.purple;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: widget.trackHeight,
        trackShape: const RoundedRectSliderTrackShape(),
        activeTrackColor: active,
        inactiveTrackColor: widget.inactiveColor ?? NeonTheme.cardAlt,
        disabledActiveTrackColor: NeonTheme.inkSoft,
        disabledInactiveTrackColor: NeonTheme.cardAlt,
        thumbColor: widget.thumbColor ?? Colors.white,
        disabledThumbColor: NeonTheme.cardAlt,
        overlayColor: active.withValues(alpha: 0.12),
        thumbShape: _CandyThumb(
          radius: widget.thumbRadius,
          borderColor: active,
          reducedMotion: NeonTheme.reducedMotion(context),
        ),
      ),
      child: Slider(
        value: widget.value,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        semanticFormatterCallback: (value) => value.toString(),
        onChanged: widget.onChanged == null ? null : _change,
        onChangeStart: (value) {
          _lastValue = widget.value;
          widget.onChangeStart?.call(value);
        },
        onChangeEnd: widget.onChangeEnd,
      ),
    );
  }
}

class _CandyThumb extends SliderComponentShape {
  const _CandyThumb({
    required this.radius,
    required this.borderColor,
    required this.reducedMotion,
  });
  final double radius;
  final Color borderColor;
  final bool reducedMotion;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final scale = reducedMotion
        ? 1.0
        : 1 + 0.15 * NeonTheme.curvePop.transform(activationAnimation.value);
    final color = Color.lerp(
      sliderTheme.disabledThumbColor,
      sliderTheme.thumbColor,
      enableAnimation.value,
    )!;
    final border = Color.lerp(
      NeonTheme.inkSoft,
      borderColor,
      enableAnimation.value,
    )!;
    final canvas = context.canvas;
    canvas.drawCircle(
      center,
      radius * scale + 2,
      Paint()
        ..color = border.withValues(alpha: 0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(center, radius * scale, Paint()..color = border);
    canvas.drawCircle(center, (radius * 0.75) * scale, Paint()..color = color);
  }
}
