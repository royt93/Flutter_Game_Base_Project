---
id: BUG-133
title: "Stabilize remaining device-only integration tests"
type: bug
layer: test
priority: P3
effort: S
source: "TECNO KJ7 smoke 2026-11-19; flaky device tests recorded in app_boot_test.dart"
---

## Evidence

- Removed the skipped Page Dots, LevelSelectGrid, and ConfettiOverlay integration cases: their showcase and widget tests cover the behavior. Page Dots also passed alone on TECNO KJ7.
- NetworkStatusBanner failed twice on TECNO KJ7 at `tester.tap(goOffline.first)` with `Bad state: No element` after `_scrollUntilVisible` and a 500 ms pump.
- Temporary device diagnostics found two `Go offline` finder results at target rect `y=123..174` while scrolling, then zero after the pump; showcase viewport was `y=100..812`. The helper returned on a finder match without ensuring visibility, so the partially clipped lazy-list item was recycled before tap.
- `_scrollUntilVisible` now calls `ensureVisible` when a target appears and confirms its rect overlaps the viewport before returning. The integration assertion is scoped to `Key('networkBannerDemo')`, avoiding similarly labelled text in stale routes.
- NetworkStatusBanner passed alone and in the full TECNO suite after this change. Existing widget suites also cover banner state/stream behavior.
- The full suite exposed a `Wave 1 P0` caller that scrolled 200 px again after `_scrollUntilVisible`, pushing `Claim All` offscreen. Removing that contradictory extra drag made the test pass alone on TECNO.
- Full suite result: 137 passed, 2 failed, 1 skipped. The other failure (`FEAT-113: Candy choice controls`) also reproduces alone on TECNO as a missing `Mode: Relaxed · Hints: on` label; tracked separately as `BUG-134`, not attributed to this helper.
- Cookbook remains skipped. Headless screen/service tests do not cover Home-to-Cookbook device navigation or real platform channels.

## Remaining follow-up

Run the complete `app_boot_test.dart` integration suite on TECNO to check for other call sites affected by the shared scroll helper. Keep Cookbook skipped until its device-only path has stable coverage or is explicitly dropped.

## Scope

No production behavior change. The shared helper and one integration test assertion changed; Cookbook's device coverage gap remains.
