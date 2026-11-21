---
id: BUG-134
title: "Investigate Candy choice controls device label"
type: bug
layer: example
effort: S
priority: P3
status: resolved
source: "TECNO KJ7 run of example/integration_test/app_boot_test.dart on 2026-11-20"
---

## Evidence

`FEAT-113: Candy choice controls respond on S24 Ultra` failed on TECNO KJ7 (`115333744A005844`) with the final label missing. The example showcase test passed using `scrollUntilVisible`; the device test used `ensureVisible` only before the first tap, then tapped the checkbox without rechecking visibility. After adding `ensureVisible` + a bounded pump before each control and checking the intermediate `Mode: Relaxed · Hints: off` state, the isolated device test passed.

## Resolution

Updated only `example/integration_test/app_boot_test.dart`: ensure the radio and checkbox controls are visible before tapping, and assert intermediate state before the final label. No production code changed. Reproduced fixed behavior on TECNO KJ7 on 2026-11-20.
