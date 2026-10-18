---
id: FEAT-163
title: FriendRequestTile — Hàng danh sách lời mời kết bạn kèm mutual friends và accept/decline
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Social & Team Meta UI (Wave 15)
---

## Vì sao cần
Màn hình danh sách bạn bè cần hiển thị các yêu cầu kết bạn đang chờ, cho phép người chơi xem thông tin tóm tắt (avatar, tên, cấp độ hoặc số bạn chung) và ra quyết định chấp nhận hoặc từ chối nhanh gọn với vùng chạm đạt chuẩn tiếp cận 48dp.

## Đề xuất phạm vi
Widget `FriendRequestTile` hiển thị:
- Thông tin `FriendRequestItem`: requestId, name, avatar, level/subtitle, mutualFriendsCount.
- 2 action buttons: `Accept` (nổi bật, NeonTheme.cyan/purple) và `Decline` (nhã nhặn, ghost/muted).
- Callbacks `onAccept(requestId)` và `onDecline(requestId)` với loading/busy state riêng biệt khi đang xử lý.
- Đảm bảo minimum touch target 48dp cho cả 2 nút bấm, không bị co cụm khi text scale lớn.
- Presentation-only: caller quản lý danh sách bạn và API gọi kết bạn.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Runtime validation requestId/name không rỗng, mutualFriendsCount >= 0, action labels không rỗng.
- [x] **Widget test**: 9 test: identity/avatar/subtitle, mutual count 0/1/200 và caller copy, callbacks, busy riêng cho accept/decline, semantics, RTL/320dp/textScale 2.0 với gutter 16dp; cả hai target >=48dp.
- [x] **Integration test (Device)**: Pixel 7 Pro, 2026-10-18: accept và decline qua caller seam, hiển thị busy và kết quả; không dùng simulator. Log `/tmp/feat163_smoke.log`.
- [x] **Golden test**: 35 ảnh normal/accept busy/decline busy/0/nhiều mutual friends qua 7 biến thể, viewport 390×844. Font test dạng khối; không dùng để kết luận typography production.
- [x] **Interruption test**: Busy action khóa cả hai callback; hết busy có thể thao tác lại.
- [x] **Network conditioning test**: N/A — caller sở hữu API và trạng thái busy.
- [x] **Memory leak & profiling test**: Test unmount khi spinner chạy kiểm tra không còn transient ticker callbacks; device profile unmount 3 lần, ScrollController không còn client. Không thay thế heap leak profiling.
- [x] **Frame rate / Jank test**: Profile Pixel 7 Pro, 100 lời mời: 2.673 frame; totalSpan p50/p95/p99 = 7,341/12,622/15,551ms; max(build,raster) = 4,520/7,672/10,015ms; 5 frame vượt 16,667ms (0,187%). Engine timings, không đo compositor missed-vsync hoặc chứng minh sustained 60 FPS. Log `/tmp/feat163_profile.log`.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] Tái dùng CommonButton/PressableScale cho spring press và reduced motion. fireHaptic light tôn trọng Settings; test xác nhận không rung khi tắt hoặc khi busy. Text lớn xếp nút dọc.

## Chạy lại
```bash
flutter test test/widget/common/friend_request_tile_test.dart test/widget/goldens/friend_request_tile_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name FEAT-163
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name FEAT-163
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/friend_request_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
