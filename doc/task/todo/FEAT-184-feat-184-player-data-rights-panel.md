---
id: FEAT-184
title: PlayerDataRightsPanel — Export and confirmed erase UI
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Privacy, Progression and Cooldown UI (Wave 23)
---

## Phạm vi
- Presentation-only panel for `PlayerDataRightsService`. Caller runs `requestExport`/`requestErasure`; the widget never receives or renders a receipt, payload, key or exception text.
- Erase needs inline confirm/cancel. Cancel never calls back. Pending call and `busy` lock every button; `busy` change clears a pending confirmation. Failure shows generic copy. Unmount during a pending call is safe.
- A callback that returns without throwing is shown as success; caller must throw when the work did not finish.

## Kiểm chứng
- [x] 7 widget tests: validation, confirm/cancel, export, generic failure, in-flight/busy lock, unmount, 320dp + 200% RTL with labeled targets.
- [x] Showcase demo is in-memory only (counters, no real data touched) and host test passes.
- [x] Local golden layout matrix (rights/confirm/busy × 7 variants) passes; macOS PNGs removed.
- [ ] Linux + Flutter 3.35.1 PNG baselines and CI verification.
- [ ] Reachable-device smoke (S24 Ultra requested; not connected, not claimed).

## Chạy lại
```bash
flutter test test/widget/common/wave23_widgets_test.dart
# From example/
flutter test test/widget_showcase_screen_test.dart --plain-name 'Wave 23'
flutter test integration_test/app_boot_test.dart -d <fresh-device-id> --dart-define=E2E_TEST=true --plain-name 'Wave 23'
```

No claim that erasure succeeded beyond what the caller's callback proves.
