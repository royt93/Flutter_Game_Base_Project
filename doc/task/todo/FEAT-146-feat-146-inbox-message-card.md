---
id: FEAT-146
title: InboxMessageCard — Thẻ thư hệ thống/quà sự kiện với badge chưa đọc và nút nhận
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Live-Ops, Retention & VIP Meta-Game UI (Wave 11)
---

## Vì sao cần
Live-ops thường gửi quà, thông báo bảo trì hoặc sự kiện qua hộp thư. Người chơi cần thấy thư nào chưa đọc, quà đính kèm và thời hạn hết hạn trước khi nhận.

## Đề xuất phạm vi
Widget `InboxMessageCard` hiển thị:
- Tiêu đề, nội dung ngắn, thời gian nhận và badge chưa đọc (`isRead` false).
- Danh sách quà đính kèm caller cung cấp (`InboxAttachment`: icon, label, amount).
- Thời hạn còn lại tự đếm trong widget (`expiresAt`); hết hạn khóa nút nhận và hiện nhãn `Expired`.
- Nút `Claim` gọi `onClaim`; chạm vào thẻ gọi `onOpen` để caller đánh dấu đã đọc.
- Presentation-only: caller xử lý trạng thái đọc/nhận và cấp phần thưởng.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate title/body không rỗng, attachment amount không âm, expiresAt hợp lệ; tính trạng thái hết hạn.
- [ ] **Widget test**: Unread badge; attachments; Claim/Open đúng callback; expired khóa nút; countdown; semantics; Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro mở, đọc, nhận thư trên showcase; không dùng simulator.
- [ ] **Golden test**: Unread/read/expired/nhiều attachment trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: App pause/resume khi countdown chạy; không gọi onClaim hai lần.
- [ ] **Network conditioning test**: N/A — widget thuần presentation; đồng bộ inbox từ server thuộc consumer.
- [ ] **Memory leak & profiling test**: MemoryWatchdog xác nhận timer countdown dispose sau unmount.
- [ ] **Frame rate / Jank test**: FrameTiming scroll danh sách 20+ thẻ; báo p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — claim callback do caller sở hữu.

## Hiệu năng & Animation
- [ ] Mỗi card chỉ giữ timer khi có `expiresAt`; list lớn dùng `ListView.builder`.
- [ ] Sustained 60 FPS benchmark: chỉ ghi khi đo scroll thật trên thiết bị vật lý.
