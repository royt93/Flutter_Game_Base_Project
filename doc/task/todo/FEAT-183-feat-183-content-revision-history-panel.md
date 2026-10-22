---
id: FEAT-183
title: ContentRevisionHistoryPanel — Metadata history and confirmed revision restore
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Content Revision Recovery (Wave 22)
---

## Phạm vi
- Presentation-only history with immutable summaries: opaque revision reference, version, safe label and formatted timestamp. No pack, typed content, JSON, secret or checksum input.
- Caller supplies current revision and performs rollback through an async callback. Current entry has no restore CTA. Selected entry shows its version and requires inline confirm/cancel.
- Callback completion is not proof of persistence or consumer reinitialization; caller must handle `SdkResult` and refresh dependent content.
- Busy/in-flight blocks actions; history/current/busy changes invalidate confirmation. Generic failure requires selection and confirmation again. Late completion is ignored after unmount or changed metadata.
- Summary list is copied; duplicate refs, missing current ref, negative version and blank strings rejected at runtime.

## Kiểm chứng
- [x] 9 unit/widget tests: validation, empty/current, exact reference callback, cancel/confirm, generic errors, busy/metadata invalidation, in-flight lock/stale failure, unmount, identifier non-rendering, 320dp + 200% RTL and labeled targets.
- [x] Caller-owned in-memory showcase and host interaction test pass; no real content mutation.
- [x] Samsung S24 Ultra (`R5CX613VZBR`, SM-S928B) smoke passes confirm/cancel and exact opaque reference. TECNO unavailable; not claimed tested.
- [x] Root non-golden regression 3,221 and example 306 tests pass before final unmount-only test addition; all 9 panel tests pass after addition.
- [x] Root/example analyzers, API compatibility, 5 quality gates and 104 tool tests pass.
- [x] Four golden states (empty/history/confirmation/busy) × 7 layout/accessibility variants pass local update-mode validation. Confirmation is tapped before every variant capture. Generated macOS PNGs removed.
- [ ] Linux + Flutter 3.35.1 PNG baselines and CI verification pending; no local PNG accepted.

## Chạy lại
```bash
flutter test test/widget/common/content_revision_history_panel_test.dart
# From example/
flutter test test/widget_showcase_screen_test.dart --plain-name 'Wave 22'
flutter test integration_test/app_boot_test.dart -d <fresh-device-id> --dart-define=E2E_TEST=true --plain-name 'Wave 22'
```

No 60 FPS, heap-leak or real rollback durability claim; device smoke verifies UI/caller seam only.
