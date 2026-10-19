---
id: FEAT-169
title: BadgeShowcaseStrip — Dải huy hiệu trưng bày trên hồ sơ với ô trống có thể chạm
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Player Profile & Cosmetics (Wave 17)
---

## Vì sao cần
Hồ sơ người chơi cần một dải nhỏ trưng bày vài huy hiệu tự chọn (ví dụ tối đa 5 ô) để khoe thành tích. `AchievementRoadmapCard` là lộ trình dài và `CollectionAlbumPanel` là kho đầy đủ; chưa có phần trưng bày cố định số ô.

## Đề xuất phạm vi
Widget `BadgeShowcaseStrip` hiển thị:
- `slotCount` ô (1–8) theo thứ tự; mỗi ô là `BadgeShowcaseItem(id, label, icon?, child?)` hoặc trống.
- Ô trống hiện dấu cộng và `emptyLabel`; chạm gọi `onSlotTap(index)` để caller mở bộ chọn huy hiệu.
- Ô có huy hiệu chạm cũng gọi `onSlotTap(index)` (đổi/xoá do caller xử lý).
- `readOnly: true` (xem hồ sơ người khác): ô trống ẩn hoặc mờ, không có chạm.
- Số ô không đổi vị trí khi nội dung thay đổi; không bị cắt khi textScale 2.0.
- Presentation-only: caller sở hữu danh sách huy hiệu, quyền sở hữu và lưu lựa chọn.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: runtime `ArgumentError` cho slotCount ngoài 1..8, badges vượt slotCount, ID rỗng/trùng, label rỗng, `icon` và `child` đồngաժամ dùng.
- [x] **Widget test**: 9 test: slots rỗng/một phần/đầy vẫn giữ số slot cố định, ô trống và ô có badge gọi đúng index, `readOnly` giữ slot nhưng không callback, semantics vị trí+tên+tap, target cao >=48dp, 8 slots lazy và cuộn ngang, 320dp+textScale 2.0+RTL thật, thay badge nội dung pulse một lần, reduced motion/unmount không ticker.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-19: tap slot rỗng và có badge qua caller seam, callback count tăng đúng; foreground lúc chạy là Home launcher; không dùng simulator. Log `/tmp/feat169_smoke.log`.
- [x] **Golden test**: 28 ảnh (empty/partial/full/readonly × 7 biến thể), viewport 390×844. Baseline sinh bằng workflow `regenerate-goldens.yml` (Linux + Flutter 3.35.1), chỉ lấy ảnh `badge_showcase_strip_*`, lockfile giữ nguyên. Font test dạng khối, không dùng để kết luận typography production.
- [x] **Interruption test**: đổi list badge giữa các lần build vẫn giữ layout; reduced motion và unmount giữa pulse không để lại ticker.
- [x] **Network conditioning test**: N/A.
- [x] **Memory leak & profiling test**: controller pulse tạo eager/dispose đúng; `transientCallbackCount == 0` sau reduced motion/unmount. Profile 50 strip, tháo tree không exception. Không thay thế heap leak profiling.
- [x] **Frame rate / Jank test**: Profile Pixel 7 Pro, 50 strip, 180 thay đổi badge + cuộn: 1.052 frame; totalSpan p50/p95/p99 = 7,489/18,055/20,598ms; max(build,raster) = 4,682/11,831/13,592ms; 5 frame vượt 16,667ms (0,475%). Engine timings, không đo compositor missed-vsync hoặc chứng minh sustained 60 FPS. Log `/tmp/feat169_profile.log`.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] Slots cuộn ngang lazy bằng `ListView.builder`; badge vừa thêm vào slot pulse 350ms (controller tạo trong initState, mount không pulse); reduced motion tắt pulse.

## Chạy lại
```bash
flutter test test/widget/common/badge_showcase_strip_test.dart test/widget/goldens/badge_showcase_strip_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-169
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-169
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/badge_showcase_strip_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
Golden local trên macOS sẽ lệch ảnh Linux; dùng CI hoặc workflow `regenerate-goldens.yml` làm chuẩn.
