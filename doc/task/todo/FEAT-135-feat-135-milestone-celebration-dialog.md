---
id: FEAT-135
title: MilestoneCelebrationDialog — Modal chúc mừng chạm mốc level quan trọng kèm pháo hoa
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Retention Expansion (Wave 8)
---

## Vì sao cần
Khi người chơi vượt qua các cột mốc lớn (Level 25, 50, 100, 500), một thông báo chúc mừng trang trọng với huy hiệu vàng, cờ hoa và danh sách quà tặng kỷ niệm tạo cảm giác gắn bó lâu dài và ghi nhận nỗ lực của người chơi.

## Đề xuất phạm vi
Widget `MilestoneCelebrationDialog` hiển thị:
- Modal in-tree dạng overlay (tuân thủ quy chuẩn `NeonDialog.overlay` / `NeonDialog.show` không phụ thuộc route để an toàn với Flame `GameWidget`).
- Huy hiệu mốc cấp độ với số level to bản và vệt sáng xoay nhẹ.
- Danh sách phần thưởng cột mốc (coins, boosters, special avatar frame).
- Nút bấm nhận thưởng gọi callback `onClaimTap`.
- Phương thức tiện ích static `MilestoneCelebrationDialog.show(context, ...)`.
- Hỗ trợ Reduced Motion: huy hiệu đứng yên, không xoay vệt sáng.

## Yêu cầu kiểm thử
- [ ] **Unit test**: Validate số level cột mốc dương, danh sách phần thưởng không rỗng.
- [ ] **Widget test**: Bấm nút nhận quà gọi `onClaimTap` và đóng dialog; Reduced Motion giữ huy hiệu tĩnh; semantics đọc rõ level cột mốc và các phần thưởng.
- [ ] **Showcase test**: Thêm nút mở dialog chúc mừng trong showcase, bấm claim cập nhật trạng thái UI.
- [ ] **Physical integration**: Kiểm tra hiển thị và tap đóng mở trên thiết bị vật lý thật (Pixel 7 Pro), không dùng simulator.

## Hiệu năng & Animation
- [ ] Huy hiệu mốc và vệt sáng xoay nằm trong `RepaintBoundary`, tự động giải phóng controller khi đóng.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
