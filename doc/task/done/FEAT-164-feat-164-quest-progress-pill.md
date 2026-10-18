---
id: FEAT-164
title: QuestProgressPill — Viên nang tiến độ nhiệm vụ ngày kèm badge nhận thưởng
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Retention & Progression UI (Wave 16)
---

## Vì sao cần
`QuestBoardPanel` là panel đầy đủ, quá lớn cho HUD màn hình chính. Cần một lối vào gọn cho biết "đã xong X/Y nhiệm vụ" và có phần thưởng chờ nhận hay chưa, để người chơi quay lại mở bảng nhiệm vụ.

## Đề xuất phạm vi
Widget `QuestProgressPill` hiển thị:
- `completed`/`total` (vd `2/3`) kèm vòng/thanh tiến độ nhỏ.
- `claimableCount`: badge số phần thưởng chờ nhận, ẩn khi 0, `9+` khi vượt 9 (tái dùng `BadgeDot`/mẫu badge của `ClanChatPreviewBar`, không viết lại animation).
- `onTap()` mở `QuestBoardPanel` do caller sở hữu.
- Trạng thái hoàn tất toàn bộ (`completed == total`) đổi sang màu/biểu tượng hoàn thành.
- Presentation-only: caller đọc `DailyQuestService`, widget không truy cập service.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: runtime `ArgumentError` cho `total <= 0`, `completed` ngoài 0..total, `claimableCount` ngoài 0..completed, `label`/`semanticLabel` rỗng.
- [x] **Widget test**: 8 test: trạng thái 0/giữa/đủ, badge 0/1/9/10/25 (`9+`), tap + target >= 48dp, semantics đọc tiến độ và số chờ nhận, 320dp + textScale 2.0 + RTL thật (kiểm tra `Directionality`), cập nhật liên tục, reduced motion.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-18: tap pill mở overlay bảng nhiệm vụ, Claim all xóa badge qua caller seam; không dùng simulator. Lưu ý: lúc chạy foreground thiết bị là app của phiên khác (`com.roy.admobwrapper`), test đã chiếm thiết bị dùng chung. Log `/tmp/feat164_smoke.log`.
- [x] **Golden test**: 35 ảnh (none/partial/claimable/many/complete × 7 biến thể), viewport 390×844. Baseline sinh bằng workflow `regenerate-goldens.yml` (Linux + Flutter 3.35.1), chỉ lấy ảnh `quest_progress_pill_*`, lockfile giữ nguyên. Font test dạng khối, không dùng để kết luận typography production.
- [x] **Interruption test**: cập nhật `completed` liên tục rồi unmount, `transientCallbackCount == 0`.
- [x] **Network conditioning test**: N/A — caller sở hữu dữ liệu.
- [x] **Memory leak & profiling test**: `transientCallbackCount == 0` sau unmount và khi reduced motion; profile unmount 3 lần không exception. Không thay thế heap leak profiling.
- [x] **Frame rate / Jank test**: Profile Pixel 7 Pro, 540 lần cập nhật: 1.183 frame; totalSpan p50/p95/p99 = 6,349/8,707/10,359ms; max(build,raster) = 3,287/4,031/4,817ms; 2 frame vượt 16,667ms (0,169%). Engine timings, không đo compositor missed-vsync hoặc chứng minh sustained 60 FPS. Log `/tmp/feat164_profile.log`.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] Thanh tiến độ dùng `TweenAnimationBuilder` 300ms; reduced motion dùng `Duration.zero`. Badge tái dùng `BadgeDot(pulse: true)`. Không tạo controller riêng.

## Chạy lại
```bash
flutter test test/widget/common/quest_progress_pill_test.dart test/widget/goldens/quest_progress_pill_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-164
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-164
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/quest_progress_pill_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
Golden local trên macOS sẽ lệch ảnh Linux; dùng CI hoặc workflow `regenerate-goldens.yml` làm chuẩn.
