import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Pure math helper: maps normalized progress [0.0..1.0] across an arc to a sector index [0..count-1] (FEAT-132).
int multiplierIndexAtNormalizedProgress(double progress, int count) {
  if (count < 2) {
    throw ArgumentError.value(count, 'count', 'must be at least 2');
  }
  if (!progress.isFinite) {
    throw ArgumentError.value(progress, 'progress', 'must be finite');
  }
  final clamped = progress.clamp(0.0, 1.0);
  final index = (clamped * count).floor();
  return index >= count ? count - 1 : index;
}

/// Pure math helper: computes the oscillating needle angle in radians for animation progress [t] in [0.0..1.0] (FEAT-132).
///
/// Returns an angle ranging from `-maxAngle` to `+maxAngle` on a smooth harmonic cosine wave.
double multiplierNeedleAngleAtProgress(
  double t, {
  double maxAngle = 0.38 * math.pi,
}) {
  if (!t.isFinite) {
    throw ArgumentError.value(t, 't', 'must be finite');
  }
  if (!maxAngle.isFinite || maxAngle <= 0) {
    throw ArgumentError.value(
      maxAngle,
      'maxAngle',
      'must be positive and finite',
    );
  }
  final p = t.clamp(0.0, 1.0);
  return -maxAngle * math.cos(p * 2 * math.pi);
}

/// Controller to drive [CoinMultiplierWheel] externally from buttons (e.g. "Stop" or "Spin again") (FEAT-132).
class CoinMultiplierWheelController extends ChangeNotifier {
  bool _isSpinning = false;
  int? _stoppedMultiplier;
  int? _stoppedIndex;

  VoidCallback? _startCallback;
  int Function()? _stopCallback;
  VoidCallback? _resetCallback;

  bool get isSpinning => _isSpinning;
  bool get isStopped => !_isSpinning && _stoppedMultiplier != null;
  int? get stoppedMultiplier => _stoppedMultiplier;
  int? get stoppedIndex => _stoppedIndex;

  void attach({
    required VoidCallback onStart,
    required int Function() onStop,
    required VoidCallback onReset,
  }) {
    _startCallback = onStart;
    _stopCallback = onStop;
    _resetCallback = onReset;
  }

  void detach() {
    _startCallback = null;
    _stopCallback = null;
    _resetCallback = null;
  }

  void start() {
    _startCallback?.call();
  }

  int stop() {
    final result = _stopCallback?.call();
    return result ?? 1;
  }

  void reset() {
    _resetCallback?.call();
  }

  void updateState({
    required bool isSpinning,
    int? stoppedMultiplier,
    int? stoppedIndex,
  }) {
    _isSpinning = isSpinning;
    _stoppedMultiplier = stoppedMultiplier;
    _stoppedIndex = stoppedIndex;
    notifyListeners();
  }
}

/// Symmetrical victory multiplier needle wheel (FEAT-132).
///
/// A harmonic oscillating needle swings back and forth across an arc of multiplier sectors
/// (default `[2, 3, 5, 10, 5, 3, 2]` with 10x jackpot in center).
/// Tapping the gauge or calling [controller.stop] stops the needle, triggers a pop celebration,
/// and returns the awarded multiplier through [onStopped].
class CoinMultiplierWheel extends StatefulWidget {
  CoinMultiplierWheel({
    super.key,
    this.multipliers = const [2, 3, 5, 10, 5, 3, 2],
    this.controller,
    this.onStopped,
    this.radius = 130,
    this.needleColor,
    this.swingDuration = const Duration(milliseconds: 1200),
    this.autoStart = true,
    this.semanticLabel,
  }) {
    if (multipliers.length < 2) {
      throw ArgumentError.value(
        multipliers.length,
        'multipliers.length',
        'must have at least 2 sectors',
      );
    }
    for (var i = 0; i < multipliers.length; i++) {
      if (multipliers[i] < 1) {
        throw ArgumentError.value(
          multipliers[i],
          'multipliers[$i]',
          'each multiplier must be at least 1',
        );
      }
    }
    if (!radius.isFinite || radius <= 0) {
      throw ArgumentError.value(
        radius,
        'radius',
        'must be positive and finite',
      );
    }
    if (swingDuration <= Duration.zero) {
      throw ArgumentError.value(
        swingDuration,
        'swingDuration',
        'must be positive',
      );
    }
  }

  final List<int> multipliers;
  final CoinMultiplierWheelController? controller;
  final void Function(int multiplier)? onStopped;
  final double radius;
  final Color? needleColor;
  final Duration swingDuration;
  final bool autoStart;
  final String? semanticLabel;

  @override
  State<CoinMultiplierWheel> createState() => _CoinMultiplierWheelState();
}

class _CoinMultiplierWheelState extends State<CoinMultiplierWheel>
    with TickerProviderStateMixin {
  late final AnimationController _swingController;
  late final AnimationController _popController;

  static const double _maxSwingAngle = 0.38 * math.pi;

  bool _stopped = false;
  double _stoppedAngle = 0.0;
  int? _stoppedIndex;
  int? _stoppedMultiplier;

  @override
  void initState() {
    super.initState();
    _swingController = AnimationController(
      vsync: this,
      duration: widget.swingDuration,
    );
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    widget.controller?.attach(onStart: _start, onStop: _stop, onReset: _reset);
  }

  @override
  void didUpdateWidget(covariant CoinMultiplierWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(
        onStart: _start,
        onStop: _stop,
        onReset: _reset,
      );
    }
    if (oldWidget.swingDuration != widget.swingDuration) {
      _swingController.duration = widget.swingDuration;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NeonTheme.reducedMotion(context)) {
      if (_swingController.isAnimating) {
        _swingController.stop();
        _swingController.value = 0.5; // center
      }
    } else if (widget.autoStart && !_stopped && !_swingController.isAnimating) {
      _start();
    }
  }

  void _start() {
    if (_stopped) {
      _reset();
      return;
    }
    if (!NeonTheme.reducedMotion(context) && !_swingController.isAnimating) {
      _swingController.repeat();
      widget.controller?.updateState(isSpinning: true);
    }
  }

  int _stop() {
    if (_stopped && _stoppedMultiplier != null) {
      return _stoppedMultiplier!;
    }

    final double angle;
    final double norm;
    if (NeonTheme.reducedMotion(context)) {
      angle = 0.0;
      norm = 0.5;
    } else {
      final t = _swingController.value;
      angle = multiplierNeedleAngleAtProgress(t, maxAngle: _maxSwingAngle);
      norm = (0.5 - 0.5 * math.cos(t * 2 * math.pi)).clamp(0.0, 1.0);
    }

    final index = multiplierIndexAtNormalizedProgress(
      norm,
      widget.multipliers.length,
    );
    final multiplier = widget.multipliers[index];

    _swingController.stop();

    setState(() {
      _stopped = true;
      _stoppedAngle = angle;
      _stoppedIndex = index;
      _stoppedMultiplier = multiplier;
    });

    if (!NeonTheme.reducedMotion(context)) {
      _popController.forward(from: 0.0);
    }

    widget.controller?.updateState(
      isSpinning: false,
      stoppedMultiplier: multiplier,
      stoppedIndex: index,
    );

    widget.onStopped?.call(multiplier);
    return multiplier;
  }

  void _reset() {
    _swingController.stop();
    _popController.stop();
    _popController.value = 0.0;

    setState(() {
      _stopped = false;
      _stoppedIndex = null;
      _stoppedMultiplier = null;
      _stoppedAngle = 0.0;
    });

    widget.controller?.updateState(isSpinning: false);

    if (widget.autoStart) {
      _start();
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _swingController.dispose();
    _popController.dispose();
    super.dispose();
  }

  Color _sectorColor(int index, int total, int multiplier) {
    if (multiplier >= 10) return NeonTheme.orange;
    if (multiplier >= 5) return NeonTheme.gold;
    if (multiplier >= 3) return NeonTheme.lime;
    return NeonTheme.cyan;
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = NeonTheme.reducedMotion(context);
    final width = widget.radius * 2;
    final height = widget.radius * 1.15;

    final String semanticsText;
    if (_stopped && _stoppedMultiplier != null) {
      semanticsText = 'Multiplier wheel stopped at x${_stoppedMultiplier!}';
    } else {
      semanticsText =
          'Multiplier wheel with sectors: ${widget.multipliers.map((m) => 'x$m').join(', ')}. Tap to stop.';
    }

    return Semantics(
      key: const ValueKey('coinMultiplierWheelSemantics'),
      container: true,
      button: !_stopped,
      label: widget.semanticLabel ?? semanticsText,
      value: _stopped ? 'x$_stoppedMultiplier' : 'spinning',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: GestureDetector(
            key: const ValueKey('coinMultiplierWheelTap'),
            behavior: HitTestBehavior.opaque,
            onTap: _stopped ? null : _stop,
            child: SizedBox(
              width: width,
              height: height,
              child: AnimatedBuilder(
                animation: Listenable.merge([_swingController, _popController]),
                builder: (context, _) {
                  final angle = _stopped
                      ? _stoppedAngle
                      : (reducedMotion
                            ? 0.0
                            : multiplierNeedleAngleAtProgress(
                                _swingController.value,
                                maxAngle: _maxSwingAngle,
                              ));

                  final popScale = reducedMotion
                      ? 1.0
                      : 1.0 +
                            0.12 *
                                NeonTheme.curvePop.transform(
                                  _popController.value,
                                );

                  return Transform.scale(
                    key: const ValueKey('coinMultiplierWheelPopScale'),
                    scale: _stopped ? popScale : 1.0,
                    child: CustomPaint(
                      size: Size(width, height),
                      painter: _MultiplierArcPainter(
                        multipliers: widget.multipliers,
                        maxAngle: _maxSwingAngle,
                        needleAngle: angle,
                        stoppedIndex: _stoppedIndex,
                        needleColor: widget.needleColor ?? NeonTheme.ink,
                        sectorColorFn: _sectorColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiplierArcPainter extends CustomPainter {
  const _MultiplierArcPainter({
    required this.multipliers,
    required this.maxAngle,
    required this.needleAngle,
    required this.stoppedIndex,
    required this.needleColor,
    required this.sectorColorFn,
  });

  final List<int> multipliers;
  final double maxAngle;
  final double needleAngle;
  final int? stoppedIndex;
  final Color needleColor;
  final Color Function(int index, int total, int multiplier) sectorColorFn;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final outerRadius = size.width * 0.46;
    final innerRadius = outerRadius * 0.55;

    final totalSectors = multipliers.length;
    final totalSweep = maxAngle * 2;
    final sectorSweep = totalSweep / totalSectors;
    // Starting angle (centered around -pi/2 (straight up))
    final startBaseAngle = -math.pi / 2 - maxAngle;

    final arcRect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerArcRect = Rect.fromCircle(center: center, radius: innerRadius);

    final sectorPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = NeonTheme.cardAlt
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw sectors
    for (var i = 0; i < totalSectors; i++) {
      final sectorStart = startBaseAngle + i * sectorSweep;
      final color = sectorColorFn(i, totalSectors, multipliers[i]);
      final isWinning = stoppedIndex == i;

      sectorPaint.color = isWinning ? color : color.withValues(alpha: 0.85);

      final path = Path()
        ..arcTo(arcRect, sectorStart, sectorSweep, false)
        ..arcTo(innerArcRect, sectorStart + sectorSweep, -sectorSweep, false)
        ..close();

      canvas.drawPath(path, sectorPaint);
      canvas.drawPath(path, borderPaint);

      // Draw text label e.g. "x5" inside sector
      final midAngle = sectorStart + sectorSweep / 2;
      final labelRadius = (outerRadius + innerRadius) / 2;
      final labelPos =
          center +
          Offset(
            math.cos(midAngle) * labelRadius,
            math.sin(midAngle) * labelRadius,
          );

      final textSpan = TextSpan(
        text: 'x${multipliers[i]}',
        style: TextStyle(
          color: Colors.white,
          fontSize: isWinning ? 16 : 14,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 4),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(labelPos.dx, labelPos.dy);
      // Orient text slightly with arc
      canvas.rotate(midAngle + math.pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Draw Needle pointing from center hub
    final needleRadius = outerRadius * 0.95;
    // needleAngle is offset from straight up (-pi/2)
    final needleTargetAngle = -math.pi / 2 + needleAngle;
    final needleTip =
        center +
        Offset(
          math.cos(needleTargetAngle) * needleRadius,
          math.sin(needleTargetAngle) * needleRadius,
        );

    final needlePaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill;

    final needlePath = Path();
    final perpAngle = needleTargetAngle + math.pi / 2;
    final baseOffset1 =
        center + Offset(math.cos(perpAngle) * 7, math.sin(perpAngle) * 7);
    final baseOffset2 =
        center - Offset(math.cos(perpAngle) * 7, math.sin(perpAngle) * 7);

    needlePath
      ..moveTo(baseOffset1.dx, baseOffset1.dy)
      ..lineTo(needleTip.dx, needleTip.dy)
      ..lineTo(baseOffset2.dx, baseOffset2.dy)
      ..close();

    canvas.drawPath(needlePath, needlePaint);

    // Center jewel hub
    final hubPaint = Paint()..color = NeonTheme.gold;
    canvas.drawCircle(center, 12, hubPaint);
    final hubBorder = Paint()
      ..color = NeonTheme.cardAlt
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, 12, hubBorder);
  }

  @override
  bool shouldRepaint(covariant _MultiplierArcPainter oldDelegate) =>
      needleAngle != oldDelegate.needleAngle ||
      stoppedIndex != oldDelegate.stoppedIndex ||
      needleColor != oldDelegate.needleColor;
}
