---
id: FEAT-171
title: ProfileStatsCard — Thẻ hồ sơ người chơi với avatar, danh hiệu và chỉ số chính
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Player Profile & Cosmetics (Wave 17)
---

## Vì sao cần
Màn hồ sơ cần một thẻ tổng hợp: avatar trong khung, tên, danh hiệu, cấp độ và vài chỉ số chính (số ván thắng, streak cao nhất, tổng thời gian chơi). Đây là phần ghép của `AvatarFrame`, `XpLevelHeader` và dữ liệu do caller cung cấp, tránh mỗi game tự dựng lại.

## Đề xuất phạm vi
Widget `ProfileStatsCard` hiển thị:
- Avatar trong `AvatarFrame` (`avatar`, `frameColor`), `name`, `title?`, `level?`.
- 2–4 ô chỉ số `ProfileStat(label, valueText, icon?)` do caller định dạng sẵn (vd `1.2K`, `3h 20m`); bố cục lưới tự xuống dòng khi chữ lớn.
- `onTap()` tuỳ chọn mở màn hồ sơ đầy đủ; `onEditAvatar()` tuỳ chọn hiện nút sửa 48dp trên avatar.
- Tên và danh hiệu dài cắt ellipsis; không tràn ở 320dp + textScale 2.0.
- Presentation-only: caller sở hữu dữ liệu, định dạng số, lưu và mở màn khác.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: runtime `ArgumentError` cho `name` rỗng, >4 stats, stat label/valueText rỗng, nhãn stat trùng, level <1/currentXp âm/xpForNextLevel <=0 hoặc nhỏ hơn currentXp, edit label/title/semanticLabel rỗng.
- [x] **Widget test**: 8 test: đủ thông tin, 0/2/4 stats, thiếu title/level, tap thẻ, tap sửa avatar không kích hoạt tap thẻ, semantics tên/danh hiệu/cấp/stats/edit, target sửa avatar >=48dp, tên dài + 4 stats + RTL thật ở 320dp/textScale 2.0, cập nhật liên tục rồi unmount.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-19: edit avatar gọi caller seam độc lập; tap thẻ mở overlay hồ sơ; không dùng simulator. Foreground lúc chạy là `com.android.settings` (Cài đặt USB); đã hỏi và được xác nhận chạy luôn. Log `/tmp/feat171_smoke.log`.
- [x] **Golden test**: 28 ảnh (complete/minimal/four_stats/long_name × 7 biến thể), viewport 390×844. Baseline sinh bằng workflow `regenerate-goldens.yml` (Linux + Flutter 3.35.1), chỉ lấy ảnh `profile_stats_card_*`, lockfile giữ nguyên. Font test dạng khối, không dùng để kết luận typography production.
- [x] **Interruption test**: cập nhật tên/XP/stats 10 lần liên tục, giá trị cuối đúng, unmount không exception/ticker.
- [x] **Network conditioning test**: N/A — avatar do caller cấp; thẻ không tải ảnh.
- [x] **Memory leak & profiling test**: test unmount và `transientCallbackCount == 0`; profile workload tháo 50 card cùng cây không exception. Không thay thế heap leak profiling.
- [x] **Frame rate / Jank test**: Profile Pixel 7 Pro, 50 thẻ, 180 lần cập nhật + cuộn: 1.271 frame; totalSpan p50/p95/p99 = 6,790/17,575/18,852ms; max(build,raster) = 3,997/11,813/12,712ms; 2 frame vượt 16,667ms (0,157%). Engine timings, không đo compositor missed-vsync hoặc chứng minh sustained 60 FPS. Log `/tmp/feat171_profile.log`.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] Ghép `AvatarFrame` và `XpLevelHeader` có sẵn; chỉ số dùng text caller-formatted. Dùng `GridView.builder` shrink-wrap (0–4 stat), một cột khi textScale >1.3. Avatar edit button riêng 48dp; overlay card không cướp sự kiện edit. Reduced motion theo widget con; không thêm animation controller.

## Chạy lại
```bash
flutter test test/widget/common/profile_stats_card_test.dart test/widget/goldens/profile_stats_card_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-171
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-171
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/profile_stats_card_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
Golden local trên macOS sẽ lệch ảnh Linux; dùng CI hoặc workflow `regenerate-goldens.yml` làm chuẩn.
