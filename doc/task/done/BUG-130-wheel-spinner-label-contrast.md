---
id: BUG-130
title: "WheelSpinner white labels fail WCAG AA on candy segment colors"
type: bug
layer: lib/presentation/widgets/common
priority: P2
effort: S
source: "FEAT-210 renderer-specific contrast audit, 2026-11-17"
---

## Evidence
`WheelSpinner` paints segment labels white over caller-provided `WheelSegment.color`. With declared opaque `backgroundColor` and built-in showcase colors, measured label contrast is 2.04:1 (cyan), 1.92:1 (lime), 1.79:1 (gold), 2.04:1 (orange), below 4.5:1 normal text. Dark colors may pass; alpha-bearing colors are composited over the required opaque background before measurement.

## Scope
Choose per segment label foreground or sector palette that meets 4.5:1 while preserving consumer-defined reward identity and not silently overriding caller colors. Keep actual painter and `contrastFindings` calculations aligned.

## Progress (2026-11-17)
- [x] `WheelSpinner` picks black/white text foreground independently for each segment using the exact composited sector/background color; source segment colors stay unchanged.
- [x] Tests cover opaque white/black and translucent segments on white, black and card backgrounds; every label has >=4.5:1 and `contrastFindings` returns empty. Source segment colors are unchanged.
- [x] Painter receives the chosen foregrounds; `shouldRepaint` includes the segment/background inputs.
- [x] CHANGELOG behavior-change entry added.

## Acceptance
- [x] Built-in showcase segment labels meet 4.5:1 on declared backgrounds.
- [x] Dark/light consumer-supplied segment fixtures demonstrate accessible behavior without overriding fills.
- [x] Existing reward colors/semantics remain unchanged; foreground behavior documented in CHANGELOG.
- [x] WheelSpinner tests pass.

## Notes
No `NeonTheme.accentText` dependency; selection is based on the actual composited caller-supplied segment color and required opaque background. Public `WheelSpinnerPainter` constructor/getter signatures and its direct-use white-label behavior are preserved; the widget uses a private subclass for adaptive label colors. Root non-golden regression suites pass (4033 tests); analyzer, API compatibility and accessibility gates pass. Physical UI check was blocked because the shared TECNO was running another app.
