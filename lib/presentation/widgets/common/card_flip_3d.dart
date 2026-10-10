import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Calculates the 3D perspective transform matrix for card flipping.
Matrix4 cardFlipTransform({
  required double angle,
  double perspective = 0.0015,
  Axis axis = Axis.horizontal,
}) {
  final matrix = Matrix4.identity();
  if (perspective > 0) {
    matrix.setEntry(3, 2, perspective);
  }
  if (axis == Axis.horizontal) {
    matrix.rotateY(angle);
  } else {
    matrix.rotateX(angle);
  }
  return matrix;
}

/// Returns true when the front face of a 3D flip card is oriented toward the camera.
bool isCardFrontVisible(double angle) {
  // cos(angle) > 0 means the normal points toward camera.
  final normalized = angle % (2 * math.pi);
  return normalized < math.pi / 2 || normalized > 3 * math.pi / 2;
}

/// Controller to trigger card flip imperatively.
class CardFlip3DController extends ChangeNotifier {
  bool _isFlipped = false;

  bool get isFlipped => _isFlipped;

  void flip() {
    _isFlipped = !_isFlipped;
    notifyListeners();
  }

  void flipToFront() {
    if (_isFlipped) {
      _isFlipped = false;
      notifyListeners();
    }
  }

  void flipToBack() {
    if (!_isFlipped) {
      _isFlipped = true;
      notifyListeners();
    }
  }
}

/// 3D Card flip with perspective transformation, automatic face switching,
/// and optional gleam sweep effect on reward reveal.
class CardFlip3D extends StatefulWidget {
  CardFlip3D({
    super.key,
    required this.front,
    required this.back,
    this.isFlipped = false,
    this.controller,
    this.onFlip,
    this.duration = NeonTheme.motionDeliberate,
    this.curve = NeonTheme.curveSmooth,
    this.perspective = 0.0015,
    this.axis = Axis.horizontal,
    this.showGleam = true,
    this.gleamColor,
    this.gleamDuration = NeonTheme.motionDeliberate,
  }) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be positive');
    }
    if (gleamDuration <= Duration.zero) {
      throw ArgumentError.value(
        gleamDuration,
        'gleamDuration',
        'must be positive',
      );
    }
    if (perspective < 0 || !perspective.isFinite) {
      throw ArgumentError.value(
        perspective,
        'perspective',
        'must be non-negative and finite',
      );
    }
  }

  final Widget front;
  final Widget back;
  final bool isFlipped;
  final CardFlip3DController? controller;
  final ValueChanged<bool>? onFlip;
  final Duration duration;
  final Curve curve;
  final double perspective;
  final Axis axis;
  final bool showGleam;
  final Color? gleamColor;
  final Duration gleamDuration;

  @override
  State<CardFlip3D> createState() => _CardFlip3DState();
}

class _CardFlip3DState extends State<CardFlip3D>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final AnimationController _gleamController;
  late CurvedAnimation _curvedFlip;
  late bool _targetFlipped;

  @override
  void initState() {
    super.initState();
    _targetFlipped = widget.controller?.isFlipped ?? widget.isFlipped;
    _flipController = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: _targetFlipped ? 1.0 : 0.0,
    );
    _curvedFlip = CurvedAnimation(
      parent: _flipController,
      curve: widget.curve,
    );

    _gleamController = AnimationController(
      vsync: this,
      duration: widget.gleamDuration,
      value: 1.0,
    );

    widget.controller?.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    final next = widget.controller!.isFlipped;
    if (next != _targetFlipped) {
      _setFlipped(next);
    }
  }

  void _setFlipped(bool flipped) {
    if (_targetFlipped == flipped) return;
    _targetFlipped = flipped;
    widget.onFlip?.call(flipped);

    if (NeonTheme.reducedMotion(context)) {
      _flipController.value = flipped ? 1.0 : 0.0;
      _gleamController.value = 1.0;
      if (mounted) setState(() {});
      return;
    }

    if (flipped) {
      _flipController.forward().then((_) {
        if (mounted && widget.showGleam) {
          _gleamController.forward(from: 0.0);
        }
      });
    } else {
      _gleamController.stop();
      _gleamController.value = 1.0;
      _flipController.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NeonTheme.reducedMotion(context) && _flipController.isAnimating) {
      _flipController.stop();
      _flipController.value = _targetFlipped ? 1.0 : 0.0;
      _gleamController.stop();
      _gleamController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant CardFlip3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChange);
      widget.controller?.addListener(_onControllerChange);
    }
    if (oldWidget.duration != widget.duration) {
      _flipController.duration = widget.duration;
    }
    if (oldWidget.gleamDuration != widget.gleamDuration) {
      _gleamController.duration = widget.gleamDuration;
    }
    if (oldWidget.curve != widget.curve) {
      _curvedFlip.curve = widget.curve;
    }
    final nextTarget = widget.controller?.isFlipped ?? widget.isFlipped;
    if (nextTarget != _targetFlipped) {
      _setFlipped(nextTarget);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChange);
    _flipController.dispose();
    _gleamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_curvedFlip, _gleamController]),
      builder: (context, _) {
        final angle = _curvedFlip.value * math.pi;
        final isFront = isCardFrontVisible(angle);
        final matrix = cardFlipTransform(
          angle: angle,
          perspective: widget.perspective,
          axis: widget.axis,
        );

        Widget visibleChild;
        if (isFront) {
          visibleChild = widget.front;
        } else {
          // Mirror back child so content isn't reversed when facing viewer.
          final backMatrix = Matrix4.identity();
          if (widget.axis == Axis.horizontal) {
            backMatrix.rotateY(math.pi);
          } else {
            backMatrix.rotateX(math.pi);
          }
          visibleChild = Transform(
            alignment: Alignment.center,
            transform: backMatrix,
            child: widget.back,
          );
        }

        Widget card = RepaintBoundary(
          child: Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.center,
              children: [
                ExcludeSemantics(
                  excluding: !isFront,
                  child: IgnorePointer(ignoring: !isFront, child: visibleChild),
                ),
                if (!isFront &&
                    widget.showGleam &&
                    _gleamController.isAnimating)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: _GleamSweepPainter(
                            progress: _gleamController.value,
                            gleamColor: widget.gleamColor ?? Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        return card;
      },
    );
  }
}

class _GleamSweepPainter extends CustomPainter {
  const _GleamSweepPainter({
    required this.progress,
    required this.gleamColor,
  });

  final double progress;
  final Color gleamColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final width = size.width;
    final height = size.height;
    final totalSpan = width + height;
    final currentOffset = progress * totalSpan * 1.5 - totalSpan * 0.25;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          gleamColor.withValues(alpha: 0.0),
          gleamColor.withValues(alpha: 0.45),
          gleamColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromLTWH(
          currentOffset - 60,
          currentOffset - 60,
          120,
          120,
        ),
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
  }

  @override
  bool shouldRepaint(covariant _GleamSweepPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.gleamColor != gleamColor;
}
