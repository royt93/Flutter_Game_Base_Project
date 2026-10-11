import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SceneWipeShape { fade, iris, star, diamond }

/// Farthest screen-corner distance from [center], enough to cover full viewport.
double sceneWipeMaxRadius(Size size, Offset center) {
  final corners = <Offset>[
    Offset.zero,
    Offset(size.width, 0),
    Offset(0, size.height),
    Offset(size.width, size.height),
  ];
  return corners.map((corner) => (corner - center).distance).reduce(math.max);
}

Path sceneWipePath({
  required Size size,
  required Offset center,
  required double progress,
  required SceneWipeShape shape,
}) {
  final t = progress.clamp(0.0, 1.0);
  final path = Path();
  if (t <= 0) return path;
  if (t >= 1 || shape == SceneWipeShape.fade) {
    return path..addRect(Offset.zero & size);
  }

  final radius = sceneWipeMaxRadius(size, center) * t;
  switch (shape) {
    case SceneWipeShape.fade:
      return path..addRect(Offset.zero & size);
    case SceneWipeShape.iris:
      return path..addOval(Rect.fromCircle(center: center, radius: radius));
    case SceneWipeShape.diamond:
      path
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius, center.dy)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - radius, center.dy)
        ..close();
      return path;
    case SceneWipeShape.star:
      final outer = radius * 2.3;
      final inner = outer * 0.45;
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? outer : inner;
        final angle = -math.pi / 2 + i * math.pi / 5;
        final point = Offset(
          center.dx + math.cos(angle) * r,
          center.dy + math.sin(angle) * r,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      return path..close();
  }
}
