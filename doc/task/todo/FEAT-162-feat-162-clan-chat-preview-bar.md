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
- [ ] **Unit test**: Validate unreadCount >= 0; message text và senderName hợp lệ.
- [ ] **Widget test**: Hiển thị message, unread badge (1..99 và 99+), empty state, tap callback, semantics, textScale 2.0.
- [ ] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) tap preview bar kích hoạt caller seam mở overlay; không dùng simulator.
- [ ] **Golden test**: `runGoldenMatrix` tin nhắn thường, 99+ badge, empty state trên baseline/dark/vi/RTL/textScale 1.3/2.0/reducedMotion, viewport 390×844.
- [ ] **Interruption test**: Cập nhật message stream nhanh không gây giật lag hoặc leak listener.
- [ ] **Network conditioning test**: N/A.
- [ ] **Memory leak & profiling test**: Kiểm tra lifecycle không leak Stream/Ticker.
- [ ] **Frame rate / Jank test**: Đo FrameTiming khi có tin nhắn mới cập nhật.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Badge dot nhịp nhẹ khi có tin mới; tắt animation khi `reducedMotion = true`.
