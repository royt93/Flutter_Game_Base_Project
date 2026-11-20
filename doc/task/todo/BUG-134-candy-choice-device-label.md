---
id: BUG-134
title: "Investigate Candy choice controls device label"
type: bug
layer: example
effort: S
priority: P3
source: "TECNO KJ7 run of example/integration_test/app_boot_test.dart on 2026-11-20"
---

## Evidence

`FEAT-113: Candy choice controls respond on S24 Ultra` fails when run alone on TECNO KJ7 (`115333744A005844`) with `Expected: exactly one matching candidate; Actual: Found 0 widgets with text "Mode: Relaxed · Hints: on"` at the final assertion (line 5581 after the scroll-helper fix). It also failed in the full TECNO integration suite. This is independent of `_scrollUntilVisible`: the test does not use that helper at the failing assertion, and isolated rerun reproduces it.

## Next step

Inspect the Candy mode/hints demo state and the test taps. Log the selected mode, hints value and rendered label after each action; determine whether the callback/state update or expected text is wrong. Keep the test assertion strict until the behavior is understood.

## Scope

No change made to Candy-choice production behavior or FEAT-113 test. Do not treat this as caused by the integration scroll-helper change.
