import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Named regions [AdaptiveGameHud] arranges HUD content into (FEAT-52).
enum HudSlot { topStart, topCenter, topEnd, bottom, side, overlay }

/// Coarse layout mode [AdaptiveGameHud] switches between — [compact] hides
/// [HudSlot.side] (no room for it), [expanded] shows every slot. Driven by
/// width alone (see [AdaptiveGameHud.compactBreakpointWidth]) rather than
/// orientation, since an orientation change on the same device already
/// changes width — a separate orientation check would just be a second
/// source of truth for the same decision.
enum HudBreakpoint { compact, expanded }

/// A small fixed gap between a safe-area/cutout/viewport edge and the slot
/// content next to it, so content never touches the edge exactly.
const double _edgeGap = 8;

/// Places HUD content ([HudSlot.topStart]/[topCenter]/[topEnd]/[bottom]/
/// [side]/[overlay]) so a game doesn't have to hand-roll safe-area, notch,
/// keyboard-inset, text-scale, RTL, and orientation handling itself every
/// time it adds a HUD element (FEAT-52).
///
/// - **Safe area/cutout**: every edge slot is padded by
///   [MediaQueryData.padding] (status bar, notch, display cutout) —
///   never wrapped in [SafeArea] itself, since [SafeArea] would consume
///   the same inset for EVERY slot even when only, say, the top needs it.
/// - **Keyboard**: [HudSlot.bottom] additionally clears
///   `MediaQueryData.viewInsets.bottom` so an on-screen keyboard never
///   covers it.
/// - **Text scale**: never overridden — slot content inherits the
///   ambient [MediaQueryData.textScaler] like any other widget; this
///   widget only reserves geometry, it doesn't clip or shrink text.
/// - **RTL**: [HudSlot.topStart]/[HudSlot.topEnd]/[HudSlot.side] use
///   [PositionedDirectional] (Flutter's own directional-aware
///   positioning) — they swap sides automatically under
///   [TextDirection.rtl], no custom logic needed.
/// - **Breakpoint**: [HudSlot.side] is hidden entirely below
///   [compactBreakpointWidth]. A descendant of any slot can read the
///   current [HudBreakpoint] via [AdaptiveGameHud.breakpointOf] to adapt
///   its own content.
/// - **Flame viewport**: an optional [flameViewportBounds] (in this
///   widget's own local coordinate space) keeps [HudSlot.topStart]/
///   [topCenter]/[topEnd]/[bottom] outside it VERTICALLY — e.g. Flame's
///   camera viewport doesn't fill the widget when the game enforces a
///   fixed aspect ratio (letterboxing), and this stops the HUD from
///   covering the visible playfield inside that box. Deliberately only
///   adjusts the top/bottom insets, not left/right — vertical
///   letterboxing is the overwhelmingly common case on phones;
///   horizontal letterboxing would additionally need to reconcile with
///   RTL start/end, which this widget doesn't attempt.
/// - **No unrelated rebuilds**: this widget never wraps [slots] in an
///   `Obx`/`GetBuilder` of its own — a slot's own reactive content (an
///   `Obx` the caller puts inside its widget) rebuilds independently of
///   [AdaptiveGameHud] itself, which only rebuilds when its own
///   [BuildContext] actually changes (a `MediaQuery`/constraints change,
///   or a new [slots] map from its parent).
class AdaptiveGameHud extends StatelessWidget {
  const AdaptiveGameHud({
    super.key,
    this.slots = const {},
    this.compactBreakpointWidth = 600,
    this.flameViewportBounds,
    this.debugShowBounds = false,
  });

  final Map<HudSlot, Widget> slots;

  /// Below this width, [HudSlot.side] is hidden — see class doc.
  final double compactBreakpointWidth;

  /// Local-coordinate bounds of Flame's actual visible viewport, if it
  /// doesn't fill this widget — see class doc.
  final Rect? flameViewportBounds;

  /// Draws a translucent outline around every active slot — a dev-only
  /// aid for tuning HUD layout, never enabled by default.
  final bool debugShowBounds;

  /// The [HudBreakpoint] the nearest ancestor [AdaptiveGameHud] resolved
  /// for its current width. Throws (via a failed `!`) if called outside
  /// one — same "must be inside" contract as `MediaQuery.of`.
  static HudBreakpoint breakpointOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_HudBreakpointScope>();
    assert(
      scope != null,
      'AdaptiveGameHud.breakpointOf() called with no AdaptiveGameHud ancestor',
    );
    return scope!.breakpoint;
  }

  Widget _slotBox(HudSlot slot) {
    final child = slots[slot];
    if (child == null) return const SizedBox.shrink();
    if (!debugShowBounds) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x80FF00FF)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final padding = mediaQuery.padding;
        final viewInsets = mediaQuery.viewInsets;
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final bounds = flameViewportBounds;

        final topInset =
            (bounds == null ? padding.top : math.max(padding.top, bounds.top)) +
            _edgeGap;
        final bottomInset =
            (bounds == null
                ? padding.bottom + viewInsets.bottom
                : math.max(
                    padding.bottom + viewInsets.bottom,
                    constraints.maxHeight - bounds.bottom,
                  )) +
            _edgeGap;
        final startPadding = (isRtl ? padding.right : padding.left) + _edgeGap;
        final endPadding = (isRtl ? padding.left : padding.right) + _edgeGap;

        final breakpoint = constraints.maxWidth >= compactBreakpointWidth
            ? HudBreakpoint.expanded
            : HudBreakpoint.compact;

        return _HudBreakpointScope(
          breakpoint: breakpoint,
          child: Stack(
            children: [
              PositionedDirectional(
                top: topInset,
                start: startPadding,
                child: _slotBox(HudSlot.topStart),
              ),
              Positioned(
                top: topInset,
                left: 0,
                right: 0,
                child: Center(child: _slotBox(HudSlot.topCenter)),
              ),
              PositionedDirectional(
                top: topInset,
                end: endPadding,
                child: _slotBox(HudSlot.topEnd),
              ),
              Positioned(
                bottom: bottomInset,
                left: padding.left + _edgeGap,
                right: padding.right + _edgeGap,
                child: _slotBox(HudSlot.bottom),
              ),
              if (breakpoint == HudBreakpoint.expanded)
                PositionedDirectional(
                  end: endPadding,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _slotBox(HudSlot.side)),
                ),
              if (slots[HudSlot.overlay] != null)
                Positioned.fill(child: _slotBox(HudSlot.overlay)),
            ],
          ),
        );
      },
    );
  }
}

class _HudBreakpointScope extends InheritedWidget {
  const _HudBreakpointScope({required this.breakpoint, required super.child});

  final HudBreakpoint breakpoint;

  @override
  bool updateShouldNotify(_HudBreakpointScope oldWidget) =>
      breakpoint != oldWidget.breakpoint;
}
