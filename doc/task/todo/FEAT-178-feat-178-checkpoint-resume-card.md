---
id: FEAT-178
title: CheckpointResumeCard — Xem checkpoint và xác nhận bắt đầu mới
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Save Continuity & Recovery (Wave 19)
---

## Vì sao cần
`CheckpointCoordinator.restoreLatest()` mutates participant state and has no read-only preview API. Consumer cần trình bày checkpoint metadata đã biết và gọi resume/start-new callback với revision cụ thể mà không restore để kiểm tra khả dụng.

## Phạm vi
- Caller cấp optional typed summary: stable revision, formatted saved-at và progress text; null là empty state.
- Resume gọi callback với revision hiện tại. Start-new luôn cần xác nhận rõ checkpoint sẽ bị bỏ; cancel không gọi callback.
- Caller sở hữu restore/create/persistence; widget không đọc storage, gọi `restoreLatest`, hoặc xóa save.
- Khi revision/busy thay đổi, confirmation/error cũ bị hủy. Callback failure hiển thị generic copy; retry cần hành động mới.

## DoD
- [x] Widget test: empty inert, start-new cancel/confirm, revision update cancels pending confirmation.
- [x] Showcase state in-memory; host test verifies cancel giữ checkpoint, confirm start-new làm trống summary.
- [x] Resume receives exact revision; unmount during async callback ignores stale error without exception.
- [ ] Golden matrix available/empty/confirm × 7 biến thể; Linux + Flutter 3.35.1 baselines chưa được lấy. Local macOS PNG không dùng.
- [ ] Root/example full suites, API compatibility and quality gates verified.

## Chạy lại
```bash
flutter test test/widget/common/save_recovery_widgets_test.dart --plain-name "checkpoint"
flutter test test/widget/goldens/save_recovery_widgets_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name "Wave 19"
```

Golden chỉ nhận từ `regenerate-goldens.yml` trên Linux + Flutter 3.35.1.
