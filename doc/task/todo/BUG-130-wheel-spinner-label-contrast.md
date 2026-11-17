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

## Acceptance
- Every built-in showcase segment label meets 4.5:1 on its declared background.
- A dark consumer-supplied segment fixture demonstrates the chosen accessible behavior.
- Existing reward colors/semantics remain understandable; change is recorded in CHANGELOG if rendered behavior changes.
- Wheel contrast tests and common widget suite pass.

## Notes
FEAT-210 currently reports findings only by explicit user choice. Do not use `NeonTheme.accentText` blindly for arbitrary consumer segment colors without a behavior/design decision.
