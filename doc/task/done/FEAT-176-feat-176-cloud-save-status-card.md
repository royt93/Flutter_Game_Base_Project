---
id: FEAT-176
title: CloudSaveStatusCard — Hiển thị trạng thái đồng bộ cloud save
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Save Continuity & Recovery (Wave 19)
---

## Vì sao cần
`CloudSaveProvider` chỉ cung cấp sign-in/upload/download; không có status stream, last-sync time hay pending count. Consumer cần trình bày trạng thái sync của chính mình mà không để widget truy cập provider hoặc save payload.

## Phạm vi
- Props caller-owned: typed status ready/syncing/synced/offline/error, pending count không âm, optional formatted last-sync text, optional async sync callback, busy flag.
- Hiển thị status bằng icon + text, pending count và last-sync text. Offline/syncing khóa CTA.
- Callback chỉ biểu thị một thao tác caller-owned; widget không tự sync, retry timer, đọc storage/network, hoặc render exception.
- Errors từ callback chỉ hiện generic safe copy; retry gọi lại callback sau tap mới.

## DoD
- [x] Widget/unit test: states, offline disable, generic callback error, async double-tap guard.
- [x] Showcase caller-owned in-memory state; host showcase test pass.
- [x] Golden matrix ready/syncing × 7 biến thể, viewport 390×844; Linux + Flutter 3.35.1 baselines committed.
- [x] Root/example suites, API compatibility and quality gates pass; CI run `39759123154` xanh.
- [x] Integration device smoke trên TECNO KJ7 (`115333744A005844`): sync callback kết thúc, trạng thái synced hiển thị.

## Chạy lại
```bash
flutter test test/widget/common/save_recovery_widgets_test.dart --plain-name "cloud status"
flutter test test/widget/goldens/save_recovery_widgets_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name "Wave 19"
```

Không sửa `CloudSaveProvider`, không hiển thị payload/credentials. Golden chỉ nhận từ `regenerate-goldens.yml` trên Linux + Flutter 3.35.1.
