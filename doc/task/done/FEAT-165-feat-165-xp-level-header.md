---
id: FEAT-165
title: XpLevelHeader — Header cấp độ người chơi kèm thanh XP tới cấp kế
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Retention & Progression UI (Wave 16)
---

## Vì sao cần
`LevelUpOverlay` chỉ xuất hiện lúc lên cấp và `RewardTrackRoad` là một đường đi dài. HUD hằng ngày thiếu một header gọn cho biết cấp hiện tại, XP đã có và XP còn thiếu tới cấp kế, nguồn dữ liệu là `PlayerProgressionService` do caller sở hữu.

## Đề xuất phạm vi
Widget `XpLevelHeader` hiển thị:
- Badge cấp `level`, tên/danh hiệu tuỳ chọn.
- Thanh XP `currentXp`/`xpForNextLevel` kèm text caller-formatted.
- Cấp tối đa (`xpForNextLevel == null`): thanh đầy, hiển thị `MAX`.
- `onTap()` tuỳ chọn mở màn thông tin cấp độ của caller.
- Presentation-only: không tính XP, không lưu, không phát level-up.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: runtime `ArgumentError` cho `level < 1`, `currentXp < 0`, `xpForNextLevel <= 0`, `currentXp > xpForNextLevel`, label/title/xpText/semanticLabel rỗng.
- [x] **Widget test**: 10 test: 0/giữa/99/đủ XP, cấp tối đa (`MAX`, thanh đầy), title và xpText caller-formatted, tap + target >= 48dp (không có tap khi `onTap == null`), semantics đọc cấp/XP/phần trăm, 320dp + textScale 2.0 + title dài + RTL thật, tăng XP liên tục rồi đổi level.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-18: bấm +20 XP thanh lên 60/100, tap header mở overlay thông tin cấp qua caller seam, đóng lại; không dùng simulator. Foreground lúc chạy là app của phiên khác (`com.roy.admobwrapper`); đã hỏi và được xác nhận chạy luôn. Log `/tmp/feat165_smoke.log`.
- [x] **Golden test**: 28 ảnh (zero/mid/almost/max × 7 biến thể), viewport 390×844. Baseline sinh bằng workflow `regenerate-goldens.yml` (Linux + Flutter 3.35.1), chỉ lấy ảnh `xp_level_header_*`, lockfile giữ nguyên. Font test dạng khối, không dùng để kết luận typography production.
- [x] **Interruption test**: tăng XP 10 lần liên tiếp rồi đổi level, giá trị cuối đúng (`Lv 6`, 5%), không crash.
- [x] **Network conditioning test**: N/A.
- [x] **Memory leak & profiling test**: `transientCallbackCount == 0` sau unmount, sau khi hết animation và khi reduced motion; profile unmount 3 lần không exception. Không thay thế heap leak profiling.
- [x] **Frame rate / Jank test**: Profile Pixel 7 Pro, 540 lần cập nhật: 1.217 frame; totalSpan p50/p95/p99 = 5,274/7,855/9,552ms; max(build,raster) = 2,669/3,776/5,155ms; 1 frame vượt 16,667ms (0,082%). Engine timings, không đo compositor missed-vsync hoặc chứng minh sustained 60 FPS. Log `/tmp/feat165_profile.log`.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] Thanh XP animate 400ms từ giá trị cũ tới mới bằng `TweenAnimationBuilder`; lúc mount bắt đầu ngay tại giá trị đích (có test `transientCallbackCount == 0`). Reduced motion dùng `Duration.zero`. Title và text XP xếp dọc để không tràn ngang khi chữ lớn/title dài. Chưa dùng motion token `NeonTheme` riêng vì kit không có token duration; dùng hằng 400ms như `QuestProgressPill`.

## Chạy lại
```bash
flutter test test/widget/common/xp_level_header_test.dart test/widget/goldens/xp_level_header_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-165
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-165
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/xp_level_header_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
Golden local trên macOS sẽ lệch ảnh Linux; dùng CI hoặc workflow `regenerate-goldens.yml` làm chuẩn.
