import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// One slice of a [WheelSpinner] — caller-supplied, same convention as
/// `LeaderboardEntry`/`VictoryCardTemplate.statLines`: this widget never
/// invents reward values or odds, it only renders and animates.
class WheelSegment {
  const WheelSegment({required this.label, required this.color, this.value});

  final String label;
  final Color color;

  /// Caller-supplied payload (e.g. a coin amount) handed back unchanged via
  /// [WheelSpinner.onSpinEnd] — this widget never reads or interprets it.
  final Object? value;
}

/// Plain `ChangeNotifier` the caller creates and owns (like a
/// `TextEditingController`, same pattern as `ScreenShakeController` in
/// `screen_shake.dart`) — triggers a spin on the [WheelSpinner] it's
/// attached to.
///
/// [resultIndex] is decided by the CALLER (the caller's own RNG/loot-table
/// logic, e.g. via `weightedRandomPick`), never by the wheel itself — same
/// "widget doesn't invent randomness" rule already applied to
/// `VictoryCardTemplate`/`LeaderboardList`.
class WheelSpinnerController extends ChangeNotifier {
  int _resultIndex = 0;

  int get resultIndex => _resultIndex;

  /// Requests a spin that lands on `segments[resultIndex]`.
  void spin(int resultIndex) {
    _resultIndex = resultIndex;
    notifyListeners();
  }
}

/// A candy-styled "wheel of fortune" — draws its own pie-slice wheel via
/// [CustomPaint] (no extra package dependency), spins to whatever index
/// [controller] requests, and reports the landed [WheelSegment] via
/// [onSpinEnd]. A fixed pointer marks the winning slice at the top; the
/// wheel itself is the only thing that rotates.
class WheelSpinner extends StatefulWidget {
  const WheelSpinner({
    super.key,
    required this.segments,
    required this.controller,
    required this.onSpinEnd,
    this.size = 260,
    this.spinDuration = const Duration(seconds: 3),
    this.extraTurns = 4,
  }) : assert(segments.length >= 2, 'WheelSpinner needs at least 2 segments');

  final List<WheelSegment> segments;
  final WheelSpinnerController controller;
  final ValueChanged<WheelSegment> onSpinEnd;
  final double size;
  final Duration spinDuration;

  /// Extra full rotations before landing, purely for visual effect.
  final int extraTurns;

  @override
  State<WheelSpinner> createState() => _WheelSpinnerState();
}

class _WheelSpinnerState extends State<WheelSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.spinDuration,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  double _startRotation = 0;
  double _endRotation = 0;
  double _rotation = 0;
  int _spinToken = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSpinRequested);
    _controller.addListener(() {
      setState(() {
        _rotation = ui.lerpDouble(_startRotation, _endRotation, _curved.value)!;
      });
    });
  }

  @override
  void didUpdateWidget(covariant WheelSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSpinRequested);
      widget.controller.addListener(_onSpinRequested);
    }
  }

  double _normalizeAngle(double angle) {
    const twoPi = 2 * math.pi;
    var a = angle % twoPi;
    if (a < 0) a += twoPi;
    return a;
  }

  void _onSpinRequested() {
    final resultIndex = widget.controller.resultIndex;
    final segmentAngle = 2 * math.pi / widget.segments.length;
    // Painter draws segment 0 starting at the top (-pi/2, see
    // WheelSpinnerPainter). The fixed pointer also sits at the top, so
    // landing segment i's *center* under it means rotating the wheel by
    // -(i + 0.5) * segmentAngle (mod 2*pi), then adding whole extra turns
    // for the visual spin.
    final targetMod = _normalizeAngle(-(resultIndex + 0.5) * segmentAngle);
    final currentTurns = (_rotation / (2 * math.pi)).floor();
    final end = (currentTurns + widget.extraTurns) * 2 * math.pi + targetMod;
    final myToken = ++_spinToken;

    if (NeonTheme.reducedMotion(context)) {
      setState(() => _rotation = end);
      widget.onSpinEnd(widget.segments[resultIndex]);
      return;
    }

    _startRotation = _rotation;
    _endRotation = end;
    _controller
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted || myToken != _spinToken) return;
        widget.onSpinEnd(widget.segments[resultIndex]);
      });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSpinRequested);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Transform.rotate(
            angle: _rotation,
            child: CustomPaint(
              key: const Key('wheelSpinnerPainter'),
              size: Size.square(widget.size),
              painter: WheelSpinnerPainter(segments: widget.segments),
            ),
          ),
          Positioned(
            top: -12,
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 44,
              color: NeonTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Public (rather than the usual underscore-private painter convention in
/// this file's siblings) so a widget test can pull `.segments` back off the
/// mounted [CustomPaint] — same testability reason as
/// `SpotlightOverlay`'s `SpotlightHolePainter`.
class WheelSpinnerPainter extends CustomPainter {
  const WheelSpinnerPainter({required this.segments});

  final List<WheelSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final segmentAngle = 2 * math.pi / segments.length;

    for (var i = 0; i < segments.length; i++) {
      final startAngle = -math.pi / 2 + i * segmentAngle;
      canvas.drawArc(
        rect,
        startAngle,
        segmentAngle,
        true,
        Paint()..color = segments[i].color,
      );

      final label = TextPainter(
        text: TextSpan(
          text: segments[i].label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius * 0.8);

      // Rotate into the slice's radial direction, paint the label along it
      // (a standard "wheel of fortune" label technique), then undo the
      // rotation before the next slice.
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + segmentAngle / 2);
      label.paint(
        canvas,
        Offset(radius * 0.5 - label.width / 2, -label.height / 2),
      );
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = NeonTheme.ink,
    );
  }

  @override
  bool shouldRepaint(covariant WheelSpinnerPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
