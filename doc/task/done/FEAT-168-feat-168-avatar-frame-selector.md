---
id: FEAT-168
title: AvatarFrameSelector — Bộ chọn khung avatar kèm trạng thái khoá và đang dùng
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Player Profile & Cosmetics (Wave 17)
---

## Vì sao cần
`AvatarFrame` chỉ là vòng viền quanh một avatar, chưa có UI để người chơi duyệt và đổi khung. Cần một bộ chọn gọn cho màn hồ sơ, hiển thị khung nào đang dùng, khung nào còn khoá, mà không sở hữu kho đồ hay logic mở khoá.

## Đề xuất phạm vi
Widget `AvatarFrameSelector` hiển thị:
- Danh sách `AvatarFrameOption(id, label, color, locked, lockHint?)`, id duy nhất.
- Mỗi ô là một `AvatarFrame` xem trước với avatar của caller (`previewChild`), nhãn dưới ô, dấu "đang dùng" cho `selectedId`.
- `onSelect(id)` cho khung đã mở; `onLockedTap(id)` cho khung còn khoá (caller mở cửa hàng hoặc hiện gợi ý), không tự đổi lựa chọn.
- Lưới cuộn lazy, số cột thích ứng theo chiều rộng và textScale; không bị cắt nhãn ở textScale 2.0.
- Presentation-only: caller sở hữu danh sách khung, trạng thái mở khoá và lưu lựa chọn.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: runtime `ArgumentError` cho id rỗng/trùng, label rỗng, `lockHint` rỗng, `selectedId` không thuộc danh sách hoặc là khung khoá, label (`selectedLabel`/`lockedLabel`/`emptyMessage`) rỗng, `maxGridHeight` <= 0 hoặc không hữu hạn.
- [x] **Widget test**: 15 test: danh sách rỗng, dấu đang dùng/khoá, chọn khung đã mở, chạm khung đang dùng không phát `onSelect`, chạm khung khoá gọi `onLockedTap` và không đổi lựa chọn, khung khoá không có `onLockedTap` thì bất hoạt, target >= 48dp, 100 khung dựng lazy, semantics (tên, đang dùng, khoá + gợi ý), 320dp + textScale 2.0 + RTL thật, đổi lựa chọn giữa lúc cuộn giữ vị trí và không phát callback, pulse một lần (mount và reduced motion không pulse), unmount giữa pulse, nhãn đậm hai dòng không tràn ở scale 1.0/1.3/2.0.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-18: chọn khung neon rồi chạm khung khoá qua caller seam, trạng thái cập nhật đúng; không dùng simulator. Foreground lúc chạy là `com.roy.admobwrapper` (app của phiên khác); đã hỏi và được xác nhận chạy luôn. Log `/tmp/feat168_smoke.log`.
- [x] **Golden test**: 21 ảnh (noselection/selected/empty × 7 biến thể), viewport 390×844. Baseline sinh bằng workflow `regenerate-goldens.yml` (Linux + Flutter 3.35.1), chỉ lấy ảnh `avatar_frame_selector_*`, lockfile giữ nguyên. Font test dạng khối, không dùng để kết luận typography production.
- [x] **Interruption test**: đổi `selectedId` giữa lúc cuộn 60 khung giữ nguyên scroll position và không phát `onSelect`.
- [x] **Network conditioning test**: N/A — caller sở hữu dữ liệu.
- [x] **Memory leak & profiling test**: `AnimationController` pulse tạo trong `initState` và dispose khi unmount (có test unmount giữa pulse); `transientCallbackCount == 0` sau unmount và khi reduced motion; profile unmount 3 lần không exception. Không thay thế heap leak profiling.
- [x] **Frame rate / Jank test**: Profile Pixel 7 Pro, cuộn 100 khung (có 20 khung khoá): 2.946 frame; totalSpan p50/p95/p99 = 6,497/10,909/13,967ms; max(build,raster) = 4,760/7,028/8,066ms; 0 frame vượt 16,667ms. Engine timings, không đo compositor missed-vsync hoặc chứng minh sustained 60 FPS. Log `/tmp/feat168_profile.log`.
- [x] **IAP & Ad mediation test**: N/A — chỉ phát `onLockedTap`, không biết nguồn mở khoá.

## Hiệu năng & Animation
- [x] `GridView.builder` lazy với `mainAxisExtent` tính theo textScale; ô được chọn pulse 450ms một lần khi đổi lựa chọn (controller bắt đầu settled nên mount không pulse); reduced motion tắt pulse; tái dùng `PressableScale` và `AvatarFrame`.
- [x] Thêm `expand: true` cho ngữ cảnh có chiều cao bị giới hạn (cùng cách `TeamRosterList`), nếu không thì cao theo nội dung và bị chặn bởi `maxGridHeight`.

## Lỗi/khác biệt đã gặp khi làm
- Lần chạy workflow golden Linux đầu tiên **fail**: ô đang chọn (chữ đậm, hai dòng) tràn 1px phía dưới trên Linux dù host macOS không tràn. Nguyên nhân: `cellExtent` tính vừa khít, số đo glyph đậm khác giữa hai nền tảng. Sửa bằng cộng 4dp dự phòng và thêm test hồi quy nhãn đậm hai dòng ở scale 1.0/1.3/2.0 (commit `bcb6f3e`).
- Showcase dài thêm làm test cũ `FEAT-123` trượt vì nút nằm ngoài viewport ảo 34000px của `_pumpShowcase`; nâng lên 38000px (không đổi hành vi widget nào).

## Chạy lại
```bash
flutter test test/widget/common/avatar_frame_selector_test.dart test/widget/goldens/avatar_frame_selector_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-168
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-168
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/avatar_frame_selector_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
Golden local trên macOS sẽ lệch ảnh Linux; dùng CI hoặc workflow `regenerate-goldens.yml` làm chuẩn.
