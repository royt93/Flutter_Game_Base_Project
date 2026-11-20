---
id: BUG-135
title: "Investigate ToastBanner ticker leak during Cookbook integration teardown"
type: bug
layer: presentation/widgets/common
effort: M
priority: P2
status: resolved
source: "TECNO KJ7 Cookbook device smoke, 2026-11-20"
---

## Evidence

A minimal `CookbookScreen: real storage round-trip on device` test was run on TECNO KJ7 (`115333744A005844`). The `VersionedJsonStore — save + load` tile is reached through `app.app()` bootstrap and reports its `round-tripped:` result, exercising `StorageService.to` backed by the real device plugin. At test teardown Flutter reports `NavigatorState ... disposed with an active Ticker`; stack points to `ToastBanner.show` → `CookbookScreen._toast` → `_run`.

The teardown failure reproduced in the host widget test that unmounted `MaterialApp` while the toast was visible, as well as on TECNO. The controller had been vsynced to `NavigatorState`, while its `OverlayEntry` lived in the root overlay and could outlive that Navigator lifecycle.

## Resolution

`ToastBanner.show()` now inserts a stateful root-overlay host that owns its `AnimationController` and auto-dismiss `Timer`; the host cancels/disposes both in `dispose()`. Normal timeout still reverses the entry before removal. A widget regression test unmounts `MaterialApp` while the toast is visible and asserts no ticker exception. Existing auto-dismiss, reduced-motion and reverse-animation tests pass. The Cookbook real-storage integration smoke passes on TECNO KJ7 with clean teardown; no production call-site changes were needed.
