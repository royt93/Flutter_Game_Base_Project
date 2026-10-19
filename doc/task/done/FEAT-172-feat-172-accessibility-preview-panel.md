---
id: FEAT-172
title: AccessibilityPreviewPanel — Preview cỡ chữ và vùng chạm 48dp ngay trong ứng dụng
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Accessibility & Player Comfort UI (Wave 18)
---

## Vì sao cần
`SettingsScreen` hiện có locale, audio, dark mode, color-blind-safe và wake-lock, nhưng người chơi chưa có cách kiểm tra nhanh giao diện ở cỡ chữ lớn hay nhận biết các vùng chạm. Panel preview giúp kiểm tra bố cục trước khi quay lại game mà không thay đổi cỡ chữ toàn hệ thống.

## Đề xuất phạm vi
Widget `AccessibilityPreviewPanel` hiển thị:
- Mẫu UI giả lập caller-provided (`preview`) trong vùng cuộn riêng, không sửa `MediaQuery` của ứng dụng cha.
- Nút preview text scale 1.0/1.3/2.0 chỉ áp dụng trong subtree preview.
- Overlay tùy chọn viền vùng tương tác bằng `ColoredBox`/`Stack` do caller cấp các `GlobalKey` mục tiêu; không suy đoán hitbox tự động.
- `onClose` tuỳ chọn đóng panel; không lưu preference hay gọi Settings API.
- Bố cục hoạt động trong parent bounded height; trạng thái/label được caller định dạng.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: runtime `ArgumentError` cho GlobalKey trùng, label rỗng, `maxHeight <= 0` hoặc không hữu hạn.
- [x] **Widget test**: 7 test: scale 1/1.3/2 chỉ đổi subtree preview, MediaQuery cha không đổi; highlight vẽ theo RenderBox của GlobalKey hiện có và đổi theo scale; không có key thì không vẽ; close callback; semantics; 320dp × 200% không overflow; toggle scale/highlight liên tục rồi unmount không ticker/callback mồ côi.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-19: mở panel, đổi 200%, close seam cập nhật count; không dùng simulator. Foreground khi chạy là `com.roy.admobwrapper`; đã hỏi và được user xác nhận chạy luôn. Log `/tmp/feat172_smoke.log`.
- [x] **Golden test**: 28 ảnh (baseline/scale 1.3/scale 2/highlight × 7 biến thể), viewport 390×844. Baseline sinh qua `regenerate-goldens.yml` trên Linux + Flutter 3.35.1; lockfile giữ nguyên. Font dạng khối, không dùng để kết luận typography production.
- [x] **Interruption test**: đổi scale/highlight rồi unmount, không callback/ticker còn sống.
- [x] **Network conditioning test**: N/A.
- [x] **Memory leak & profiling test**: không controller riêng; sau unmount `transientCallbackCount == 0`.
- [x] **Frame rate / Jank test**: profile 100 GlobalKey target + 100 lần đổi kích thước/scale trên Pixel 7 Pro: 287 frame; totalSpan p50/p95/p99 = 4,910/8,390/11,911ms; max(build,raster) = 3,046/4,192/7,219ms; 1 frame vượt 16,667ms (0,348%). Engine timings; không chứng minh sustained 60 FPS. Log `/tmp/feat172_profile.log`.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] Scale/highlight đổi tức thì, không animation/controller riêng; chỉ đo lại highlight rect sau frame/scroll.

## Lỗi gặp khi làm
- Golden semantic audit bắt hai widget con tappable không có tên screen-reader; custom scale controls và target toggle được gắn label/action riêng.
- Test 320dp × 200% phát hiện target label + toggle tràn 273px; thay row cứng bằng Wrap và panel full-width theo constraints.

## Chạy lại
```bash
flutter test test/widget/common/accessibility_preview_panel_test.dart test/widget/goldens/accessibility_preview_panel_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-172
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-172
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/accessibility_preview_panel_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
Golden local macOS chỉ kiểm tra layout; baselines chuẩn lấy từ Linux workflow `regenerate-goldens.yml` theo `CLAUDE.md`.
