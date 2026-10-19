---
id: FEAT-174
title: HapticPatternPicker — Chọn và nghe thử pattern rung có kiểm soát preference
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Accessibility & Player Comfort UI (Wave 18)
---

## Vì sao cần
Kit đã có `HapticChoreographer`, `HapticPattern`, `HapticLevel` và Settings lưu haptic enabled/soft mode, nhưng chưa có control để người chơi nghe thử các pattern ngắn theo ngữ cảnh (soft/standard/strong). UI phải tôn trọng tắt haptics và soft mode, đồng thời không phát rung liên tục khi preview.

## Đề xuất phạm vi
Widget `HapticPatternPicker` hiển thị:
- Các lựa chọn 1–3 `HapticPatternOption(id, label, pattern)`; một lựa chọn đang dùng do caller truyền.
- Nút chọn gọi `onSelect(id)`; nút preview chỉ phát một lần pattern qua caller-supplied `HapticChoreographer`/callback seam.
- Nút preview disabled khi `hapticsEnabled == false`, và disable mọi thao tác khi `busy` (pattern đang phát).
- `onPreview(pattern)` là seam; widget không tự ghi settings hoặc tạo choreographer trong build.
- Semantics có label, selected/busy/disabled; không hiển thị thông tin kỹ thuật pulse/delay cho người chơi.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: runtime validation option count 1..3, id rỗng/trùng, label rỗng, selectedId sai, preview label rỗng; null selection hợp lệ.
- [x] **Widget test**: 8 test: chọn và preview đúng pattern, off chỉ chọn null, preference disabled/busy chặn preview và select, targets >=48dp, semantics selected/disabled/preview action, 320dp+textScale 2.0+RTL, method-channel xác nhận haptics enabled/soft-mode; soft mode downgrades heavy→medium qua helper thật.
- [x] **Integration test (Device)**: TECNO KJ7, 2026-10-19: chọn Reward và preview seam vào busy, app chạy không exception; không simulator. Foreground ban đầu là Home. Log `/tmp/feat174_smoke_tecno.log`.
- [x] **Golden test**: 28 ảnh (normal/selected/busy/disabled × 7 biến thể), viewport 390×844. Baseline từ Linux `regenerate-goldens.yml` + Flutter 3.35.1; lockfile giữ nguyên.
- [x] **Interruption test**: host test bảo busy khóa thao tác; perf test đổi 100 trạng thái liên tục/unmount không exception hoặc ticker mồ côi.
- [x] **Network conditioning test**: N/A.
- [x] **Memory leak & profiling test**: widget không tạo choreographer/timer; controller thuộc caller. Host/perf unmount test sạch.
- [x] **Frame rate / Jank test**: TECNO KJ7 profile: 3 options, 100 thay đổi selection/busy, 209 frame; totalSpan p50/p95/p99 = 4,421/5,387/7,194ms; max(build,raster) = 2,736/3,336/4,006ms; 0 slow frames trên 16,667ms. `previews=0` (benchmark không kích hoạt haptic playback để tránh 100 rung thật); engine timings, không đo compositor missed-vsync hoặc chứng minh 60 FPS bền vững. Log `/tmp/feat174_profile.log`.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] Chọn/preview dùng `PressableScale`; preview busy do caller điều khiển, no timer/controller trong widget; reduced-motion được kế thừa từ PressableScale.

## Chạy lại
```bash
flutter test test/widget/common/haptic_pattern_picker_test.dart test/widget/goldens/haptic_pattern_picker_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-174
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-174
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/haptic_pattern_picker_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
Goldens local macOS khác Linux; dùng CI/workflow regenerate theo `CLAUDE.md`.
