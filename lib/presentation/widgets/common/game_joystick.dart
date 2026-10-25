import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Eight-way direction emitted by [GameJoystick].
enum GameJoystickDirection { idle, up, upRight, right, downRight, down, downLeft, left, upLeft }

/// Caller-owned virtual joystick. Direction and unit vector reset to neutral
/// on pointer release or cancellation.
class GameJoystick extends StatefulWidget {
  const GameJoystick({
    super.key,
    required this.semanticLabel,
    required this.onDirectionChanged,
    this.size = 144,
    this.knobSize = 56,
  });

  final String semanticLabel;
  final void Function(GameJoystickDirection direction, Offset unitVector)
  onDirectionChanged;
  final double size;
  final double knobSize;

  static Offset vectorFor(GameJoystickDirection direction) {
    final angle = switch (direction) {
      GameJoystickDirection.idle => null,
      GameJoystickDirection.up => -math.pi / 2,
      GameJoystickDirection.upRight => -math.pi / 4,
      GameJoystickDirection.right => 0.0,
      GameJoystickDirection.downRight => math.pi / 4,
      GameJoystickDirection.down => math.pi / 2,
      GameJoystickDirection.downLeft => 3 * math.pi / 4,
      GameJoystickDirection.left => math.pi,
      GameJoystickDirection.upLeft => -3 * math.pi / 4,
    };
    if (angle == null) return Offset.zero;
    return Offset(math.cos(angle), math.sin(angle));
  }

  static GameJoystickDirection directionFor(Offset vector) {
    if (vector == Offset.zero) return GameJoystickDirection.idle;
    final angle = math.atan2(vector.dy, vector.dx);
    final index = ((angle / (math.pi / 4)).round() + 2) % 8;
    return GameJoystickDirection.values[index + 1];
  }

  @override
  State<GameJoystick> createState() => _GameJoystickState();
}

class _GameJoystickState extends State<GameJoystick> {
  Offset _vector = Offset.zero;
  GameJoystickDirection _direction = GameJoystickDirection.idle;

  void _handlePanDown(DragDownDetails details) => _update(details.localPosition);

  void _handlePanStart(DragStartDetails details) => _update(details.localPosition);

  void _handlePanUpdate(DragUpdateDetails details) => _update(details.localPosition);

  void _update(Offset localPosition) {
    final radius = widget.size * 0.34;
    final offset = localPosition - Offset(widget.size / 2, widget.size / 2);
    final distance = offset.distance;
    final vector = distance > radius ? offset / distance : offset / radius;
    final direction = GameJoystick.directionFor(vector);
    if (vector == _vector) return;
    setState(() {
      _vector = vector;
      _direction = direction;
    });
    widget.onDirectionChanged(direction, vector);
  }

  void _handlePanEnd(DragEndDetails details) => _release();

  void _handlePanCancel() => _release();

  void _release() {
    if (_vector == Offset.zero) return;
    setState(() {
      _vector = Offset.zero;
      _direction = GameJoystickDirection.idle;
    });
    widget.onDirectionChanged(_direction, _vector);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    child: SizedBox.square(
      dimension: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: _handlePanDown,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onPanCancel: _handlePanCancel,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _JoystickBase(size: widget.size),
            Transform.translate(
              offset: _vector * (widget.size * 0.34),
              child: _JoystickKnob(size: widget.knobSize),
            ),
          ],
        ),
      ),
    ),
  );
}

class _JoystickBase extends StatelessWidget {
  const _JoystickBase({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: NeonTheme.cyan.withValues(alpha: 0.20),
      border: Border.all(color: NeonTheme.cyan, width: 3),
    ),
  );
}

class _JoystickKnob extends StatelessWidget {
  const _JoystickKnob({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: NeonTheme.cyan,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: NeonTheme.glow(NeonTheme.cyan, blur: 8),
    ),
  );
}
