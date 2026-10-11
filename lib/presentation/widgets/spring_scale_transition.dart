import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/neon_theme.dart';

enum SpringMotionPreset { bouncy, gentle, snappy }

SpringDescription springDescriptionFor(SpringMotionPreset preset) =>
    switch (preset) {
      SpringMotionPreset.bouncy => NeonTheme.springBouncy,
      SpringMotionPreset.gentle => NeonTheme.springGentle,
      SpringMotionPreset.snappy => NeonTheme.springSnappy,
    };

class SpringSimulationController {
  SpringSimulationController({
    required TickerProvider vsync,
    this.preset = SpringMotionPreset.snappy,
    double initialValue = 0,
  }) {
    if (!initialValue.isFinite) {
      throw ArgumentError.value(initialValue, 'initialValue', 'must be finite');
    }
    _controller = AnimationController.unbounded(
      vsync: vsync,
      value: initialValue,
    );
  }

  final SpringMotionPreset preset;
  late final AnimationController _controller;
  bool _disposed = false;

  Animation<double> get animation => _controller.view;
  double get value => _controller.value;
  double get velocity => _controller.velocity;
  bool get isAnimating => _controller.isAnimating;

  void animateTo(
    double target, {
    SpringMotionPreset? preset,
    bool reducedMotion = false,
  }) {
    if (!target.isFinite) {
      throw ArgumentError.value(target, 'target', 'must be finite');
    }
    if (reducedMotion) {
      jumpTo(target);
      return;
    }
    final simulation = SpringSimulation(
      springDescriptionFor(preset ?? this.preset),
      _controller.value,
      target,
      _controller.velocity,
    );
    _controller.animateWith(simulation).whenCompleteOrCancel(() {
      if (!_disposed) _controller.value = target;
    });
  }

  void jumpTo(double value) {
    _controller.stop();
    _controller.value = value;
  }

  void dispose() {
    _disposed = true;
    _controller.dispose();
  }
}

class SpringScaleTransition extends StatelessWidget {
  const SpringScaleTransition({
    super.key,
    required this.controller,
    required this.child,
    this.begin = 0.85,
    this.end = 1,
    this.opacity = false,
  });

  final SpringSimulationController controller;
  final Widget child;
  final double begin;
  final double end;
  final bool opacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation,
      child: child,
      builder: (context, child) {
        final value = controller.value;
        final scale = begin + (end - begin) * value;
        return Opacity(
          opacity: opacity ? value.clamp(0.0, 1.0) : 1,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}
