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
- After FEAT-113 visibility handling, ToastBanner lifecycle ownership, and minimal Cookbook coverage were fixed, the full TECNO suite passed: 142 passed, 0 skipped.
- Replaced the seven-tile device test with one `VersionedJsonStore — save + load` smoke through `app.app()`/`_goToCookbook` and real `StorageService.to`. After the ToastBanner controller moved into the root-overlay entry's state, the test passed on TECNO KJ7 with clean teardown. Headless screen/service tests still cover the other tiles.

## Remaining follow-up

The only remaining skipped integration case is unrelated to this task's removed tests. Keep its reason documented at the test site and continue to run the device suite on TECNO when it is changed.

## Scope

No production behavior change from the scroll-helper task. The helper/assertion fix and the minimal Cookbook device smoke now have on-device passing coverage; ToastBanner lifecycle was fixed under BUG-135.
