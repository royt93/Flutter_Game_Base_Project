import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Which edge of the bubble the triangular pointer nub sits on — i.e. which
/// side points at the thing being called out. `up` = nub on the top edge
/// (bubble sits below its target), `down` = nub on the bottom edge (bubble
/// sits above its target).
enum TooltipPointerDirection { up, down }

/// Small candy-styled speech-bubble container for coach-mark/hint use cases.
///
/// A rounded rect body + a triangular pointer nub on one edge, drawn as a
/// single [Path] via [CustomPainter] (fill + stroke) so the nub reads as
/// part of the same shape rather than a separately-clipped overlay. Wraps
/// arbitrary [child] content — pass a `Text` directly for a plain label, or
/// use [TooltipBubble.text] as a shortcut for that common case.
class TooltipBubble extends StatelessWidget {
  const TooltipBubble({
    super.key,
    required this.child,
    this.color,
    this.direction = TooltipPointerDirection.up,
    this.nubAlign = 0.5,
    this.padding = const EdgeInsets.symmetric(
      horizontal: NeonTheme.s16,
      vertical: NeonTheme.s8,
    ),
  });

  /// Convenience for the plain-text-label case.
  TooltipBubble.text(
    String text, {
    super.key,
    this.color,
    this.direction = TooltipPointerDirection.up,
    this.nubAlign = 0.5,
    this.padding = const EdgeInsets.symmetric(
      horizontal: NeonTheme.s16,
      vertical: NeonTheme.s8,
    ),
  }) : child = Text(
         text,
         textAlign: TextAlign.center,
         style: TextStyle(
           color: NeonTheme.ink,
           fontSize: 14,
           fontWeight: FontWeight.w800,
         ),
       );

  final Widget child;

  /// Defaults to [NeonTheme.purple] — nullable because a `NeonTheme` color
  /// field is no longer a compile-time constant.
  final Color? color;
  final TooltipPointerDirection direction;

  /// Horizontal position of the nub, 0 (left) .. 1 (right) of the bubble
  /// width. Clamped away from the rounded corners inside the painter.
  final double nubAlign;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? NeonTheme.purple;
    final nubPadding = EdgeInsets.only(
      top: direction == TooltipPointerDirection.up
          ? _BubblePainter.nubHeight
          : 0,
      bottom: direction == TooltipPointerDirection.down
          ? _BubblePainter.nubHeight
          : 0,
    );
    return DecoratedBox(
      // Glow/drop shadow applied to the bounding box rather than the exact
      // bubble+nub silhouette — close enough for a small nub, and far
      // simpler than hand-blurring the path on canvas.
      decoration: BoxDecoration(
        boxShadow: [
          ...NeonTheme.glow(color, blur: 14, spread: 1, intensity: 0.6),
          ...NeonTheme.drop(y: 3, blur: 10),
        ],
      ),
      child: CustomPaint(
        painter: _BubblePainter(
          color: color,
          direction: direction,
          nubAlign: nubAlign,
        ),
        child: Padding(
          padding: nubPadding,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.color,
    required this.direction,
    required this.nubAlign,
  });

  final Color color;
  final TooltipPointerDirection direction;
  final double nubAlign;

  static const double nubWidth = 16;
  static const double nubHeight = 10;
  static const double borderWidth = 3;
  static const double radius = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final up = direction == TooltipPointerDirection.up;
    final bodyTop = up ? nubHeight : 0.0;
    final bodyBottom = up ? size.height : size.height - nubHeight;
    final inset = borderWidth / 2;
    final bodyRect = Rect.fromLTRB(
      inset,
      bodyTop + inset,
      size.width - inset,
      bodyBottom - inset,
    );
    final rrect = RRect.fromRectAndRadius(
      bodyRect,
      const Radius.circular(radius),
    );

    final minCenter = radius + nubWidth / 2;
    final maxCenter = size.width - radius - nubWidth / 2;
    final nubCenterX = (size.width * nubAlign).clamp(
      minCenter <= maxCenter ? minCenter : size.width / 2,
      minCenter <= maxCenter ? maxCenter : size.width / 2,
    );

    final nubPath = Path();
    if (up) {
      nubPath
        ..moveTo(nubCenterX - nubWidth / 2, bodyTop + inset)
        ..lineTo(nubCenterX, 0)
        ..lineTo(nubCenterX + nubWidth / 2, bodyTop + inset)
        ..close();
    } else {
      nubPath
        ..moveTo(nubCenterX - nubWidth / 2, bodyBottom - inset)
        ..lineTo(nubCenterX, size.height)
        ..lineTo(nubCenterX + nubWidth / 2, bodyBottom - inset)
        ..close();
    }

    final combined = Path.combine(
      PathOperation.union,
      Path()..addRRect(rrect),
      nubPath,
    );

    canvas.drawPath(combined, Paint()..color = NeonTheme.card);
    canvas.drawPath(
      combined,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.direction != direction ||
      oldDelegate.nubAlign != nubAlign;
}
