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
- [x] **Unit test**: `levelPathNodeCenter` tạo toạ độ S-curve xen kẽ trái/giữa/phải; validate `level >= 1`, `starsEarned` 0..3, `width`/`rowHeight` dương, danh sách node không rỗng.
- [x] **Widget test**: Tap node hoàn thành/mở khóa gọi `onLevelTap`; node khóa không gọi callback; node hiện tại có hiệu ứng pulse; Reduced Motion tắt pulse; semantics đọc đúng level, trạng thái và số sao; bản đồ bottom-up đặt level 1 ở dưới cùng.
- [x] **Showcase test**: Tích hợp bản đồ 6 node uốn lượn vào showcase; tap node level 4 cập nhật trạng thái do caller sở hữu (không phải toast).
- [x] **Physical integration**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), không dùng simulator.

## Hiệu năng & Animation
- [x] Đường chấm bi Bézier vẽ trong `RepaintBoundary`; controller pulse dispose khi unmount.
- [ ] Sustained 60 FPS benchmark: chưa đo; không tuyên bố đạt 60 FPS.
