import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../neon_dialog.dart';
import 'panel_card.dart';

/// Onboarding/tutorial coach-mark: dims the whole screen except a
/// highlighted "hole" cut around a target widget's actual on-screen bounds,
/// plus a guidance callout with a dismiss button.
///
/// An in-tree overlay like [NeonDialog.overlay] — not a route — so it works
/// the same whether the caller sits above a plain screen or a full-screen
/// Flame `GameWidget` (see CLAUDE.md's "Dialog pattern"). Mount it as a
/// `Positioned.fill` sibling of the already-built target inside a `Stack`,
/// same as `RewardPopup`/`ConfettiOverlay` are used in the demo screen —
/// the target must already be laid out (its [GlobalKey] attached to a
/// mounted widget) for the hole position to be correct.
class SpotlightOverlay extends StatefulWidget {
  const SpotlightOverlay({
    super.key,
    required this.targetKey,
    required this.message,
    required this.onDismiss,
    this.title,
    this.buttonLabel = 'Got it',
    this.color,
    this.holeRadius = 16,
    this.holePadding = 8,
    this.dimColor,
  });

  /// The already-mounted target widget to highlight.
  final GlobalKey targetKey;
  final String message;
  final String? title;
  final String buttonLabel;
  final VoidCallback onDismiss;

  /// Defaults to [NeonTheme.purple] — nullable because a `NeonTheme` color
  /// field is no longer a compile-time constant.
  final Color? color;

  /// Corner radius of the cut-out hole.
  final double holeRadius;

  /// Extra margin added around the target's actual bounds before cutting
  /// the hole, so the highlight isn't a pixel-tight outline.
  final double holePadding;

  /// Defaults to a black scrim if omitted.
  final Color? dimColor;

  @override
  State<SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<SpotlightOverlay> {
  @override
  void initState() {
    super.initState();
    // On the very first build, `targetKey`'s RenderBox has been created but
    // not yet laid out (layout runs once for the whole tree after the build
    // phase), so its bounds aren't known yet. Rebuild once after that first
    // frame to pick up the real, laid-out position/size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// The target's current on-screen bounds (global coordinates), inflated
  /// by [SpotlightOverlay.holePadding] — null if `targetKey` isn't attached
  /// to a laid-out widget yet.
  Rect? get _targetRect {
    final renderObject = widget.targetKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return (renderObject.localToGlobal(Offset.zero) & renderObject.size)
        .inflate(widget.holePadding);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect;
    final screenSize = MediaQuery.of(context).size;
    final entranceDuration = NeonTheme.reducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    return Stack(
      children: [
        Positioned.fill(
          // Blocks all interaction with whatever is underneath until
          // dismissed — same "barrier consumes the tap" behavior as
          // `NeonDialog.overlay`'s barrier.
          child: GestureDetector(
            onTap: widget.onDismiss,
            // Plain fade (no bounce — a bounce on a full-screen dim would
            // look off) so the very first appearance isn't a hard snap,
            // matching every other overlay in the kit
            // (NeonDialog/ToastBanner/RewardPopup all animate in).
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: entranceDuration,
              curve: Curves.easeOut,
              builder: (context, t, child) =>
                  Opacity(opacity: t.clamp(0.0, 1.0), child: child),
              child: CustomPaint(
                key: const Key('spotlightOverlayPainter'),
                painter: SpotlightHolePainter(
                  hole: rect,
                  radius: widget.holeRadius,
                  dimColor:
                      widget.dimColor ?? Colors.black.withValues(alpha: 0.72),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        if (rect != null)
          _Callout(
            rect: rect,
            screenSize: screenSize,
            title: widget.title,
            message: widget.message,
            buttonLabel: widget.buttonLabel,
            color: widget.color ?? NeonTheme.purple,
            onDismiss: widget.onDismiss,
            entranceDuration: entranceDuration,
          ),
      ],
    );
  }
}

/// Cuts a rounded-rect hole out of a full-screen dim scrim using
/// `Path.combine`'s `difference` op. Public (rather than the usual
/// underscore-private painter convention in this file's siblings) so a
/// widget test can pull `.hole` back off the mounted [CustomPaint] and
/// assert it against the target's real `RenderBox` bounds.
class SpotlightHolePainter extends CustomPainter {
  const SpotlightHolePainter({
    required this.hole,
    required this.radius,
    required this.dimColor,
  });

  /// Global-coordinate bounds of the cut-out hole, or null to dim the
  /// entire screen with no hole (target not laid out yet).
  final Rect? hole;
  final double radius;
  final Color dimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final scrim = hole == null
        ? full
        : Path.combine(
            PathOperation.difference,
            full,
            Path()..addRRect(
              RRect.fromRectAndRadius(hole!, Radius.circular(radius)),
            ),
          );
    canvas.drawPath(scrim, Paint()..color = dimColor);
  }

  @override
  bool shouldRepaint(covariant SpotlightHolePainter oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.radius != radius ||
      oldDelegate.dimColor != dimColor;
}

/// Guidance text + dismiss button, placed below the hole if there's more
/// room below the target than above it, otherwise above.
class _Callout extends StatelessWidget {
  const _Callout({
    required this.rect,
    required this.screenSize,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.color,
    required this.onDismiss,
    required this.entranceDuration,
  });

  final Rect rect;
  final Size screenSize;
  final String? title;
  final String message;
  final String buttonLabel;
  final Color color;
  final VoidCallback onDismiss;
  final Duration entranceDuration;

  @override
  Widget build(BuildContext context) {
    final spaceBelow = screenSize.height - rect.bottom;
    final placeBelow = spaceBelow >= rect.top;
    return Positioned(
      left: NeonTheme.s24,
      right: NeonTheme.s24,
      top: placeBelow ? rect.bottom + NeonTheme.s16 : null,
      bottom: placeBelow ? null : screenSize.height - rect.top + NeonTheme.s16,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: entranceDuration,
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
        ),
        child: PanelCard(
          borderColor: color,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: TextStyle(
                    color: NeonTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: NeonTheme.s8),
              ],
              Text(
                message,
                style: TextStyle(
                  color: NeonTheme.inkSoft,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: NeonTheme.s16),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 120,
                  child: NeonDialogButton(
                    action: NeonDialogAction(
                      label: buttonLabel,
                      color: color,
                      onTap: onDismiss,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
