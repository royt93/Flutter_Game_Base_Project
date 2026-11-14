---
id: BUG-127
title: "WinStreakFlameHud overflows horizontally at 320dp and 2x text"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-200 phase 2q viewport sweep, 2026-11-14"
---

## Evidence
At 320dp width and 2.0× text scale, the HUD row overflowed horizontally by 5.7px. The streak-count and multiplier labels grew with text scaling while the HUD kept fixed horizontal spacing.

## Fix
Wrap both labels in `FittedBox(fit: BoxFit.scaleDown)` so they shrink only when required by the available row width.

## Verification
- [x] Phase 2q sweep reproduces the original overflow and passes with the fix.
- [x] Existing `win_streak_flame_hud_test.dart` passes.
- [x] Full viewport sweep passes 144 tests; targeted analyzer clean.
