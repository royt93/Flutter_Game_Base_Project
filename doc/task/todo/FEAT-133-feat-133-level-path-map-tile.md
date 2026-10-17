---
id: FEAT-133
title: LevelPathMapTile — Node bản đồ màn chơi uốn lượn phong cách saga kèm đường cong nối
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & Retention Expansion (Wave 8)
---

## Vì sao cần
Thay vì lưới level dạng phẳng (`LevelSelectGrid`), hầu hết các casual puzzle game đỉnh cao (Candy Crush, Royal Match, Homescapes) dẫn người chơi qua một bản đồ hành trình uốn lượn dạng chữ S (S-curve saga path) với các nút tròn có 1-3 sao, cờ mốc và vệt đường nối chấm bi.

## Đề xuất phạm vi
Widget `LevelPathMapTile` hiển thị:
- Một node màn chơi tròn với số thứ tự level, số sao đạt được (0-3 sao), cờ đánh dấu nếu là level hiện tại.
- Đường nối cong Bézier (`CustomPainter`) nối sang node trước/sau theo hướng zig-zag trái/phải.
- Trạng thái node: đã hoàn thành (màu kẹo sáng + sao), hiện tại (nhịp đập nhẹ pulse), và bị khóa (màu xám / icon ổ khóa).
- Callback `onLevelTap(int level)` do caller sở hữu.
- Widget thuần dữ liệu: caller cung cấp mảng level states, widget dựng đường nối uốn lượn liên tục.

## Yêu cầu kiểm thử
- [ ] **Unit test**: Kiểm tra tính toán tọa độ cong Bézier giữa các điểm node liên tiếp, validate số level dương và số sao 0..3.
- [ ] **Widget test**: Tap vào node mở khóa gọi `onLevelTap`; node khóa không gọi callback; node hiện tại có hiệu ứng pulse; Reduced Motion tắt pulse.
- [ ] **Showcase test**: Tích hợp danh sách 6-8 node uốn lượn vào showcase, tap level hiện toast thông báo.
- [ ] **Physical integration**: Kiểm tra hiển thị đường cong và tap mượt trên thiết bị vật lý thật (Pixel 7 Pro), không dùng simulator.

## Hiệu năng & Animation
- [ ] Vẽ đường cong nối trong `RepaintBoundary`, tái sử dụng path và paint đối tượng.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
