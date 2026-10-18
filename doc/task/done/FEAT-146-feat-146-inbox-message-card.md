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
- [x] **Unit test**: Validate title/body không rỗng, attachment amount không âm, expiresAt hợp lệ; tính trạng thái hết hạn (`inbox_message_card_test.dart`, 9 test pass).
- [x] **Widget test**: Unread badge; attachments; Claim/Open đúng callback; expired khóa nút; countdown; semantics; Reduced Motion.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) mở, đọc, nhận thư trên showcase thật; không dùng simulator.
- [x] **Golden test**: Unread/read+claimed/expired trên light/dark/vi/RTL/textScale/reducedMotion (`inbox_message_card_golden_test.dart`).
- [x] **Interruption test**: Unmount hủy timer countdown an toàn, không rò timer.
- [x] **Network conditioning test**: N/A — widget thuần presentation; đồng bộ inbox từ server thuộc consumer.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-146.
- [ ] **Frame rate / Jank test**: CHƯA ĐO FrameTiming scroll danh sách 20+ thẻ.
- [x] **IAP & Ad mediation test**: N/A — claim callback do caller sở hữu.

## Hiệu năng & Animation
- [x] Timer chỉ chạy khi có `expiresAt` chưa hết hạn; hủy ngay khi expired hoặc unmount.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.
