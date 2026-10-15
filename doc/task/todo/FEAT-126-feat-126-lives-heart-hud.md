---
id: FEAT-126
title: LivesHeartHud — Cụm hiển thị mạng chơi trái tim kèm đếm ngược hồi sinh
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Live-Ops Expansion (Wave 6)
---

## Vì sao cần
Hệ thống mạng (Candy Crush hearts) với số lượng mạng hữu hạn (ví dụ: 5 tim) và đếm ngược hồi mạng là trụ cột monetisation và retention của game casual.

## Đề xuất phạm vi
Widget `LivesHeartHud` hiển thị icon trái tim 3D candy, số lượng mạng hiện tại (`maxLives`, `currentLives`), nhãn đếm ngược hồi mạng (`nextRefillCountdown`), và nút (+) mở popup nạp mạng / xin bạn bè khi chạm vào.

## Yêu cầu kiểm thử
- [ ] **Unit test**: Kiểm tra trạng thái full mạng, hết mạng, tính toán hiển thị chuỗi đếm ngược và validate số mạng hợp lệ.
- [ ] **Widget test**: Kiểm tra bấm nút (+) gọi callback `onRefillTap`, tim nhấp nháy khi mạng đầy hoặc nguy hiểm (0 mạng), accessibility semantics đọc đúng số mạng.
- [ ] **Showcase test**: Tích hợp cụm mạng vào showcase có nút tiêu tốn mạng và nạp lại mạng, cập nhật UI chính xác.
- [ ] **Physical integration**: Kiểm tra hiển thị và tap trên thiết bị thật TECNO KJ7 / physical device, không dùng simulator.

## Hiệu năng & Animation
- [ ] Hiệu ứng tim đập nhẹ dùng `AnimatedBuilder` tách biệt, giải phóng controller khi unmount.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
