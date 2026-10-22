---
id: FEAT-177
title: SaveConflictPicker — Chọn bản save local/cloud có xác nhận
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Save Continuity & Recovery (Wave 19)
---

## Vì sao cần
`VersionedJsonStore` có conflict handler đồng bộ và mặc định last-write-wins; UI không thể chờ user bên trong handler an toàn. Consumer cần cho user xem metadata hai bản và chọn trước một action riêng, không expose generic save object.

## Phạm vi
- Caller cấp hai summary an toàn: stable revision, formatted saved-at và progress text; widget không nhận raw save values.
- User chọn local/cloud, xem rõ bản được giữ và bản bị thay thế, rồi xác nhận destructive choice. Cancel không gọi callback.
- Callback async nhận choice và cả hai revision; caller phải revalidate revision hiện hành trước khi áp dụng. Widget không gọi `syncWith`, merge, hoặc tự ghi save.
- Khi revision đổi, selection/confirmation/error cũ bị hủy. Error chỉ hiện generic copy; retry cần chọn và xác nhận lại.

## DoD
- [x] Unit/widget test: typed summary validation, choice/cancel/confirm, exact revisions, revision change invalidates confirmation.
- [x] Showcase in-memory only; host test pass.
- [ ] Golden matrix unselected/confirm × 7 biến thể; Linux + Flutter 3.35.1 baselines chưa được lấy. Local macOS PNG không dùng.
- [x] Callback generic error requires fresh selection; revision change during in-flight callback ignores stale completion and releases lock without applying stale error.
- [ ] Root/example full suites, API compatibility and quality gates verified.

## Chạy lại
```bash
flutter test test/widget/common/save_recovery_widgets_test.dart --plain-name "conflict"
flutter test test/widget/goldens/save_recovery_widgets_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name "Wave 19"
```

`VersionedSyncConflictHandler<T>` là sync; không await dialog trong handler. Handler throw sẽ fallback last-write-wins, không dùng throw làm stale guard. Golden chỉ nhận từ `regenerate-goldens.yml` trên Linux + Flutter 3.35.1.
