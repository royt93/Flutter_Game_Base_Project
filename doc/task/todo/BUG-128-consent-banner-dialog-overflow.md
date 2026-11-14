---
id: BUG-128
title: "Consent dialog overflows on short screens"
type: bug
layer: lib/widgets/common + lib/widgets/dialog
priority: P2
effort: S
source: "FEAT-200 phase 2s viewport sweep, 2026-11-14"
---

## Evidence
`ConsentBanner` opened `NeonDialog` whose panel content was not scrollable or height-constrained. It overflowed by 80 px at 320×480 dp, 110 px at 640×320 dp, and also overflowed at 2× text on compact screens.

## Fix
`NeonDialog.panel` now caps panel height to the available viewport (minus 48 dp vertical margin) and allows panel content to scroll. This keeps the consent actions reachable without truncating copy.

## Verification
- [x] ConsentBanner sweep passes five default viewports and two compact 2× text viewports.
- [x] Existing `consent_banner_test.dart` passes.
- [x] Full viewport sweep passes 157 tests.
- [x] Targeted analyzer reports no issues.
