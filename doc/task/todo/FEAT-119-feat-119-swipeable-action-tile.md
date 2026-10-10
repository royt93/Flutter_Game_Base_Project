---
id: FEAT-119
title: SwipeableActionTile — Thẻ danh sách vuốt lộ nút xoá/nhận quà kèm haptic
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Hòm thư nhận quà, danh sách thông báo, danh sách quest thường cần thao tác vuốt ngang để thực hiện nhanh hành động (Xoá, Nhận quà, Đánh dấu đã đọc).

## Đề xuất phạm vi
Widget SwipeableActionTile bọc bất kỳ list item nào, hỗ trợ vuốt sang trái/phải để lộ các nút hành động nền, có độ đàn hồi lò xo (overscroll resistance) và rung haptic khi trượt qua ngưỡng.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra trạng thái vuốt, ngưỡng kích hoạt trigger threshold và gọi đúng callback tương ứng.
- [ ] **Widget test**: Mô phỏng gesture drag ngang, kiểm tra thẻ trượt theo ngón tay để lộ icon hành động phía sau.
- [ ] **Integration test**: Vuốt thẻ thư trong màn hình thông báo trên thiết bị thật, kiểm tra cảm giác kéo mượt và phản hồi rung.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Khóa cuộn dọc khi đang vuốt ngang, tái sử dụng Transform dịch chuyển offset.
