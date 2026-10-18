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
- [ ] **Unit test**: Validate requestId và name không rỗng, mutualFriendsCount >= 0.
- [ ] **Widget test**: Hiển thị tên, subtitle, mutual friends, callbacks accept/decline, busy state, semantics, textScale 2.0.
- [ ] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) tap accept/decline qua caller seam; không dùng simulator.
- [ ] **Golden test**: `runGoldenMatrix` normal, busy state, 0 và nhiều mutual friends trên baseline/dark/vi/RTL/textScale 1.3/2.0/reducedMotion, viewport 390×844.
- [ ] **Interruption test**: Tap nút khi busy không kích hoạt thêm callback.
- [ ] **Network conditioning test**: N/A.
- [ ] **Memory leak & profiling test**: Lifecycle check khi unmount khỏi danh sách.
- [ ] **Frame rate / Jank test**: Đo FrameTiming trong danh sách cuộn.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Nút bấm có hiệu ứng nhấn nảy phản hồi xúc giác; hỗ trợ `reducedMotion`.
