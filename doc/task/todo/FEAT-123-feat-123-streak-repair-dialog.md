---
id: FEAT-123
title: StreakRepairDialog — Hộp thoại phục hồi chuỗi đăng nhập lỡ dở
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Live-Ops Expansion (Wave 6)
---

## Vì sao cần
Người chơi rất tiếc chuỗi ngày đăng nhập dài (7-30 ngày) khi lỡ quên 1 ngày; tính năng Streak Freeze / Streak Repair (như Duolingo, Royal Match) cho phép dùng đá quý hoặc xem quảng cáo để giữ chuỗi, tăng mạnh retention D7/D30.

## Đề xuất phạm vi
Widget `StreakRepairDialog` hiển thị số ngày chuỗi bị đứt (ví dụ: chuỗi 14 ngày), hoạt họa ngọn lửa băng giá/tan băng, và 2 nút hành động caller-owned (Dùng Gem để sửa chuỗi hoặc Bỏ qua / Bắt đầu lại).

## Yêu cầu kiểm thử
- [ ] **Unit test**: Kiểm tra logic tính toán chi phí sửa chuỗi, số ngày khôi phục và callback xác nhận.
- [ ] **Widget test**: Kiểm tra hiển thị đúng số ngày chuỗi, bấm nút repair gọi callback tương ứng và tự đóng dialog; Reduced Motion bỏ qua hoạt họa tan băng.
- [ ] **Showcase test**: Tích hợp nút mở dialog mẫu trong showcase, cập nhật trạng thái chuỗi sau khi bấm sửa.
- [ ] **Physical integration**: Mở và tương tác mượt mà trên thiết bị thật TECNO KJ7 / physical device, không dùng simulator.

## Hiệu năng & Animation
- [ ] Hoạt họa nảy lửa/băng sử dụng `Transform.scale` và `CurvedAnimation`, tự giải phóng controller khi đóng dialog.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
