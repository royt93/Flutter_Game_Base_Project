---
id: FEAT-162
title: ClanChatPreviewBar — Thanh preview tin nhắn clan kèm unread badge và quick tap
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Social & Team Meta UI (Wave 15)
---

## Vì sao cần
HUD game casual cần một thanh preview gọn gàng ở màn hình chính hoặc phòng chờ, giúp người chơi thấy ngay tin nhắn mới nhất của đồng đội, số tin chưa đọc và tap để mở phòng chat đầy đủ mà không chiếm dụng toàn bộ màn hình.

## Đề xuất phạm vi
Widget `ClanChatPreviewBar` hiển thị:
- Tin nhắn mới nhất: senderName, senderAvatar, message text (cắt ngắn 1 dòng có ellipsis), timestamp đã format.
- Badge số tin chưa đọc (`unreadCount`), tự ẩn khi count = 0, hiển thị `99+` khi vượt quá 99.
- Callback `onTap()` mở giao diện chat đầy đủ của caller.
- Hỗ trợ trạng thái rỗng `No messages yet` khi chưa có tin nhắn nào trong phòng.
- Presentation-only: caller quản lý websocket/stream/danh sách tin nhắn.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate unreadCount >= 0; senderName/message cùng null hoặc cùng không rỗng; labels không rỗng.
- [x] **Widget test**: Message/avatar/timestamp, badge 0/1/99/100/1000, empty state, callback, semantics có full message và count thật; 320dp/RTL/textScale 2.0 với gutter 16dp.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-18: tap preview mở overlay caller, đóng overlay, unread về 0; không dùng simulator. Log `/tmp/feat162_smoke.log`.
- [x] **Golden test**: 21 ảnh normal/99+/empty qua 7 biến thể, viewport 390×844. Font test dùng glyph dạng khối; không coi ảnh này là bằng chứng typography production.
- [x] **Interruption test**: 30 cập nhật nhanh trong widget test; 540 cập nhật trong profile device.
- [x] **Network conditioning test**: N/A — caller sở hữu network/stream.
- [x] **Memory leak & profiling test**: Widget không sở hữu stream; test tắt reduced motion/unmount kiểm tra không còn transient ticker callback. Profile mount/unmount 3 lần, cập nhật notifier sau unmount không exception. Không thay thế heap leak profiling.
- [x] **Frame rate / Jank test**: Profile Pixel 7 Pro: 1.940 frame; totalSpan p50/p95/p99 = 6,134/11,235/12,545ms; max(build,raster) = 3,415/6,097/6,877ms; 0 frame vượt 16,667ms. Engine timings, không đo compositor missed-vsync hoặc chứng minh sustained 60 FPS. Log `/tmp/feat162_profile.log`.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] Tái dùng `BadgeDot(pulse: true)` khi unread > 0; reduced motion tắt ticker; không tạo stream/controller mới trong preview.

## Chạy lại
```bash
flutter test test/widget/common/clan_chat_preview_bar_test.dart test/widget/goldens/clan_chat_preview_bar_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-162
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-162
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/clan_chat_preview_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
